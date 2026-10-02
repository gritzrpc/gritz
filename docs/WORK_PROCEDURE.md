# Gritz 作業手順書

> **Gritz**（gRPC + blitz） — fork フレンドリーな Ruby 向け gRPC フレームワーク
>
> 作成日: 2026-10-02 ／ 関連: [ROADMAP.md](./ROADMAP.md), [DESIGN.md](./DESIGN.md)

---

## 0. この手順書の使い方

- 各作業には **ID**（例: `T2-03`）を振っている。ブランチ名・PR タイトル・コミットメッセージに ID を含める。
- 各作業の **DoD（完了の定義）** を満たしたら、PR を作成してレビューを受ける。
- 設計から逸脱する判断が必要になったら、作業を止めて ADR を起票する（11.5 のテンプレート参照）。
- 手順中のコマンドは Linux（devcontainer）上での実行を前提とする。

---

## 1. 開発環境の準備

### 1.1 必要なもの

| ツール | 用途 | 備考 |
|---|---|---|
| CRuby 3.3 以上 | 実装・テスト | `Process.warmup` と `async-grpc` が 3.3 以上を要求 |
| Docker / devcontainer | Linux 環境 | macOS では `SO_REUSEPORT` の挙動が異なるため必須 |
| `grpc-tools` gem | `grpc_tools_ruby_protoc` によるコード生成 | — |
| `grpcurl` | 手動での動作確認 | — |
| `ghz` | 負荷試験 | — |
| `smem` | PSS / USS の計測 | — |
| `kind` | Kubernetes シナリオテスト | Phase 3 以降 |

### 1.2 devcontainer

```dockerfile
# .devcontainer/Dockerfile
FROM ruby:3.4-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential git curl procps smem jq \
    && rm -rf /var/lib/apt/lists/*
# grpcurl / ghz は各リリースページからバイナリを取得する。
# 使用バージョンは .tool-versions に固定し、ここでもそのバージョンを参照すること。
```

```jsonc
// .devcontainer/devcontainer.json（抜粋）
{
  "build": { "dockerfile": "Dockerfile" },
  // tcp_migrate_req の検証（S-02）に必要。net.* はネットワーク名前空間単位の sysctl
  "runArgs": ["--sysctl", "net.ipv4.tcp_migrate_req=1"]
}
```

**DoD**: devcontainer 内で `ruby -v`、`grpcurl -version`、`ghz --version` が通る。

---

## 2. リポジトリ初期化（T0-01）

```bash
mkdir gritz && cd gritz && git init
mkdir -p gems examples spikes bench/{scenarios,results} docs/{adr,spikes,guides}

# 最初は core と grpc アダプタとメタ gem の 3 つから始める
for g in gritz-core gritz-grpc gritz; do
  (cd gems && bundle gem "$g" --test=rspec --ci=github --linter=rubocop --mit --no-coc)
done
```

ルートに開発用 `Gemfile` を置き、各 gem を `path:` で参照する。

```ruby
# Gemfile（ルート）
source "https://rubygems.org"

gem "gritz-core", path: "gems/gritz-core"
gem "gritz-grpc", path: "gems/gritz-grpc"
gem "gritz",      path: "gems/gritz"

# CI のマトリクスで grpc gem のバージョンを切り替える
gem "grpc", ENV["GRPC_VERSION"] if ENV["GRPC_VERSION"]

group :development, :test do
  gem "grpc-tools"
  gem "rspec"
  gem "rubocop"
  gem "simplecov"
  gem "yard"
  gem "bundler-audit"
end
```

**規約**

- 全ファイルに `# frozen_string_literal: true` を付ける。
- 公開 API には YARD を書き、`@api public` / `@api private` を明示する。
- オートロードには Zeitwerk を使う（各 gem の `lib/gritz.rb` で loader を設定）。
- コミットは Conventional Commits 形式にする（`feat(T2-03): add ForkGuard`）。

**DoD**: `bundle exec rspec` と `bundle exec rubocop` がルートから全 gem に対して通り、CI（11.4）が緑になる。

---

## 3. Phase 0: スパイク手順

各スパイクは `spikes/s0x_*/` に最小コードを置き、結果を `docs/spikes/S-0x.md`（11.6 のテンプレート）に記録する。**スパイクのコードは本体に流用しない**（捨てる前提で書く）。

### S-01: Clean master + `SO_REUSEPORT` による分散とスケール

**準備**

```proto
// spikes/s01_reuseport/proto/echo.proto
syntax = "proto3";
package echo;

service EchoService {
  rpc Echo (EchoRequest) returns (EchoReply);
  rpc Burn (BurnRequest) returns (EchoReply);   // CPU バウンド
}

message EchoRequest { string message = 1; }
message BurnRequest { int32 ms = 1; }
message EchoReply   { string message = 1; int32 pid = 2; }
```

```bash
cd spikes/s01_reuseport
bundle exec grpc_tools_ruby_protoc -I proto --ruby_out=lib --grpc_out=lib proto/echo.proto
```

**サーバ**

```ruby
# spikes/s01_reuseport/server.rb
require "grpc"   # require だけでは C-core が初期化されないことも、このスパイクで確認する
$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "echo_services_pb"

WORKERS = Integer(ENV.fetch("WORKERS", 4))

class EchoImpl < Echo::EchoService::Service
  def echo(req, _call)
    Echo::EchoReply.new(message: req.message, pid: Process.pid)
  end

  def burn(req, _call)
    t0 = Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID)
    nil while Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID) - t0 < req.ms / 1000.0
    Echo::EchoReply.new(pid: Process.pid)
  end
end

pids = Array.new(WORKERS) do
  fork do
    # ここで初めて gRPC オブジェクトを生成する（Clean Master）
    server = GRPC::RpcServer.new(pool_size: 8, server_args: { "grpc.so_reuseport" => 1 })
    server.add_http2_port("0.0.0.0:50051", :this_port_is_insecure)
    server.handle(EchoImpl)
    server.run_till_terminated_or_interrupted(%w[TERM INT])
  end
end

%w[TERM INT].each do |sig|
  trap(sig) { pids.each { |pid| Process.kill("TERM", pid) rescue nil } }
end
Process.waitall
```

**分散の確認（接続単位）**

```ruby
# spikes/s01_reuseport/tally.rb
require "grpc"
$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "echo_services_pb"

CONNS = Integer(ENV.fetch("CONNS", 64))

tally = Hash.new(0)
CONNS.times do
  # 同一引数のチャネルはサブチャネル（接続）を共有しうるため、ローカルプールで接続を分ける
  stub = Echo::EchoService::Stub.new(
    "localhost:50051", :this_channel_is_insecure,
    channel_args: { "grpc.use_local_subchannel_pool" => 1 }
  )
  tally[stub.echo(Echo::EchoRequest.new(message: "x")).pid] += 1
end
tally.sort.each { |pid, n| puts "#{pid}\t#{n}" }
puts "max/min = #{(tally.values.max.to_f / tally.values.min).round(2)}"
```

**スケールの確認**

```bash
for w in 1 2 4 8; do
  WORKERS=$w bundle exec ruby server.rb & SERVER=$!
  sleep 3
  ghz --insecure --proto proto/echo.proto --call echo.EchoService/Burn \
      -d '{"ms":5}' -c 64 --connections 64 -z 30s \
      --format json localhost:50051 > ../../bench/results/s01_w${w}.json
  kill -TERM $SERVER; wait $SERVER
done
jq '.rps' ../../bench/results/s01_w*.json
```

**記録する項目**: 接続分布の max/min、ワーカー数ごとの RPS、ワーカー数に対する RPS の比、エラー数、使用した grpc gem のバージョン。

**合格基準**: 4 ワーカーの RPS が 1 ワーカーの 3.4 倍以上（コア数 ≥ 4 の環境で）。

### S-02: ドレイン時のエラー

1. S-01 のサーバを `WORKERS=4` で起動し、`ghz` で 60 秒の負荷をかける（`--connections 64`）。
2. 負荷中にワーカー 1 台へ `kill -TERM <pid>` を送る。
3. `ghz` のエラー件数と内訳（`UNAVAILABLE` 等）を記録する。
4. 以下の 4 条件で比較する。

| 条件 | `tcp_migrate_req` | 停止前に新ワーカー起動 |
|---|---|---|
| A | 0 | なし |
| B | 1 | なし |
| C | 0 | あり |
| D | 1 | あり |

5. `server_args` に `"grpc.max_connection_age_ms" => 10_000` を加え、停止後に接続が残りのワーカーへ再分散されるまでの時間を測る。

**合格基準**: 条件 D でエラー 0 件。

### S-03: ForkGuard の検出方式

1. `require "grpc"` 直後に fork した子プロセスで RPC が成功する（＝未初期化である）ことを確認する。
2. 次のフックを差し込み、master で `GRPC::Core::Channel.new` を呼ぶと検出できることを確認する。

```ruby
module ForkGuardProbe
  MASTER_PID = Process.pid

  def initialize(*args, **kw, &blk)
    if Process.pid == MASTER_PID
      warn "gRPC object created in master: #{self.class}\n  #{caller_locations(1, 5).join("\n  ")}"
    end
    super
  end
end

[GRPC::Core::Channel, GRPC::Core::Server,
 GRPC::Core::ChannelCredentials, GRPC::Core::ServerCredentials].each do |klass|
  klass.prepend(ForkGuardProbe)
end
```

3. C 定義クラスに対して `prepend` が効かない、または引数の受け渡しで問題が起きる場合は、`singleton_class.prepend` で `new` をフックする方式を試す。
4. `GRPC::ClientStub.new` 経由の生成も検出できることを確認する。

**合格基準**: 上記 4 クラスと `ClientStub` 経由の生成をすべて、発生箇所付きで検出できる。

### S-04: `fork_mode :grpc_fork_support`

1. `GRPC_ENABLE_FORK_SUPPORT=1` を設定し、master でクライアント RPC を行う。
2. `GRPC.prefork` → `fork` → 子で `GRPC.postfork_child`、親で `GRPC.postfork_parent` の順に呼ぶ。
3. 子プロセスで `RpcServer` を生成し、サービスを提供できるかを確認する。
4. master で Bidi を使った場合の挙動を記録する（非対応のため、エラー内容を確認する）。

**記録する項目**: 動作可否、エラー内容、`prefork` にかかった時間。

### S-05: Reflection 用の記述子取得

1. 生成された `*_pb.rb` が直列化済みの記述子を `add_serialized_file` で登録しているかを確認する。
2. `Google::Protobuf::DescriptorPool#add_serialized_file` を `prepend` でフックし、バイト列を収集できるかを試す。
3. 代替として `FileDescriptor` から `FileDescriptorProto` を得る API が使えるかを確認する。
4. 収集したデータで `grpcurl list` / `grpcurl describe` に応答する最小のリフレクションサーバを書く。

### S-06: `async-grpc` の相互運用性

1. `grpc_tools_ruby_protoc` で生成したメッセージクラスを `async-grpc` サーバで使えるかを確認する。
2. 4 種の RPC を実装し、grpc gem のクライアントと `grpcurl` から呼ぶ。
3. ステータス、トレーラ、`grpc-status-details-bin`、デッドラインの扱いを確認する。
4. master で bind したソケットを fork 後の子で accept する構成を試す。

### S-07: Rails の preload と PSS

1. `rails new` で作ったアプリ（モデル数十・gem 数十程度）に S-01 相当のサービスを載せる。
2. preload なし／あり／あり + `Process.warmup` の 3 条件で、4 ワーカーを起動する。
3. 10 分間の負荷後に `smem -k -c "pid name uss pss rss"` で計測する。

**記録する項目**: 各条件におけるワーカー 1 台あたりの PSS / USS。

### S-08: 名前とリポジトリ

- 名前は **Gritz** に決定済み。`gritz` / `gritz-core` / `gritz-grpc` / `gritz-async` / `gritz-rails` / `gritz-otel` は 2026-10-02 時点で RubyGems 上で未使用であることを確認済み。
- GitHub の org / リポジトリ名と商標の衝突を確認する。
- 名前を確保するため、上記 6 つの gem をプレースホルダ（v0.0.1、README のみ）として早めに公開する。
- リポジトリに LICENSE（MIT）、SECURITY.md、CONTRIBUTING.md を置く。

### Phase 0 の締め

1. 全スパイクのレポートを揃える。
2. ADR 001〜003 を「Accepted」または「Rejected」に更新する。
3. ROADMAP.md 7 章の判断ポイントに沿って Go/No-Go を判断し、結果を記録する。

---

## 4. Phase 1 作業手順（コア v0.1）

依存関係の順に並べている。上から順に着手する。

| ID | タスク | 主な成果物 | DoD |
|---|---|---|---|
| T1-01 | 設定オブジェクトと DSL | `configuration.rb`, `dsl.rb` | 全項目に既定値・型検証・環境変数マッピングがあり、不正値で起動前にエラーになる |
| T1-02 | エラー階層 | `errors.rb` | 17 種すべてのステータスコードにクラスがあり、`fail!` からリッチ詳細付きで生成できる |
| T1-03 | `Context` | `context.rb` | Fiber storage で分離され、`Thread.new` / `Fiber.new` に継承されることをテストで確認 |
| T1-04 | `Call` 抽象と `InMemoryCall` | `call.rb`, `testing/in_memory_call.rb` | 4 種の RPC を `InMemoryCall` で表現できる |
| T1-05 | `MethodDescriptor` と `Router` | `method_descriptor.rb`, `router.rb` | 生成 `Service` の `rpc_descs` からルート表を作り、二重 bind と未実装 RPC を検出する |
| T1-06 | `Controller` | `controller.rb`, `controller/filters.rb` | 4 種の RPC、フィルタ、`rescue_from`、リクエスト毎インスタンスを満たす |
| T1-07 | `Dispatcher` とミドルウェアスタック | `dispatcher.rb`, `middleware/stack.rb` | `insert_before` / `insert_after` / `use` / `delete` / `swap` が動作する |
| T1-08 | 標準ミドルウェア | `middleware/*.rb` | `RequestId` / `Context` / `Logging` / `ExceptionMapper` が既定スタックに入る |
| T1-09 | GrpcCore アダプタ | `gritz-grpc/.../bridge.rb`, `server.rb`, `call.rb` | grpcurl から 4 種の RPC を呼べる。リッチエラーが `grpc-status-details-bin` に載る。server streaming の逐次送信を確認済み |
| T1-10 | テストヘルパ | `testing/rpc_helper.rb`, マッチャ | `rpc(...)` と `raise_rpc_error` が RSpec / Minitest で使える |
| T1-11 | CLI | `cli.rb`, `exe/gritz` | `gritz start`（シングルモード）と `gritz routes` が動く |
| T1-12 | サンプルとドキュメント | `examples/hello`, README | クイックスタートを第三者が 5 分以内に完了できる |

### T1-09 の実装メモ

- ブリッジクラスは `Class.new(service_class)` で作り、`rpc_descs` の各エントリに対して `define_method` でハンドラを定義する。
- grpc gem のハンドラシグネチャは RPC 種別ごとに異なる。

| 種別 | grpc gem が呼ぶシグネチャ | 戻り値 |
|---|---|---|
| unary | `(req, call)` | レスポンス |
| client streaming | `(call)` | レスポンス |
| server streaming | `(req, call)` | Enumerable |
| bidi | `(requests_enum, call)` | Enumerable |

- server streaming と bidi は `Enumerator.new { |y| dispatcher.call(GrpcCoreCall.new(..., writer: y)) }` を返す。
- 期限・メタデータ・キャンセル状態をビューオブジェクトから取得する方法を実装前に確認し、結果をコードコメントに残す。

---

## 5. Phase 2 作業手順（マルチプロセス v0.2）

| ID | タスク | 主な成果物 | DoD |
|---|---|---|---|
| T2-01 | Master のメインループ | `supervisor/master.rb`, `signal_queue.rb` | self-pipe 方式でシグナルを処理し、`waitpid` で回収・補充できる |
| T2-02 | `WorkerHandle` とステータスパイプ | `worker_handle.rb`, `status_channel.rb` | JSON Lines の送受信、パイプ破損時の安全な扱い |
| T2-03 | ForkGuard | `fork_guard.rb` | S-03 の方式で実装。`:raise` / `:warn` / `:off` の 3 モード |
| T2-04 | `Worker::Runner` | `worker/runner.rb`, `heartbeat.rb` | フック実行 → トランスポート起動 → ready 報告 → シグナル待ち。終了時は `exit!` |
| T2-05 | フックと preload | `dsl.rb` 拡張 | `before_fork` / `on_worker_boot` / `on_worker_shutdown`、`preload_app!`、`Process.warmup` |
| T2-06 | グレースフルシャットダウン | `master.rb`, `runner.rb` | DESIGN.md 6.7 の手順どおりに動く（統合テストで固定） |
| T2-07 | タイムアウト監視 | `master.rb` | `worker_boot_timeout` / `worker_timeout` 超過で KILL し、補充する |
| T2-08 | `TTIN` / `TTOU` / `HUP` | `master.rb` | ワーカー数の増減とログの再オープン |
| T2-09 | `gritz check` | `cli.rb` | preload 後に ForkGuard の違反を列挙し、違反があれば終了コード 1 |
| T2-10 | `fork_mode :grpc_fork_support` | `fork_guard.rb`, `master.rb` | S-04 の結果に基づき実装。Linux 以外では起動時エラー |
| T2-11 | `Testing::Cluster` と統合テスト | `testing/cluster.rb`, `spec/integration/cluster/` | 起動・TERM・KILL・TTIN/TTOU・ハングの各シナリオ |
| T2-12 | 長時間負荷試験 | `bench/scenarios/soak.yml` | 1 時間でリーク・ハングなし（RSS 推移をグラフで記録） |

### T2-01 の骨格

```ruby
# frozen_string_literal: true

module Gritz
  module Supervisor
    class Master
      SIGNALS = %w[TERM INT QUIT USR1 USR2 TTIN TTOU HUP CHLD].freeze

      def initialize(config)
        @config = config
        @workers = {}            # pid => WorkerHandle
        @signals = []
        @self_r, @self_w = IO.pipe
        @shutting_down = false
      end

      def run
        install_traps
        @config.preload! if @config.preload_app?
        Process.warmup if Process.respond_to?(:warmup)
        maintain_worker_count

        until @shutting_down && @workers.empty?
          ios = [@self_r, *@workers.values.map(&:status_io)]
          ready, = IO.select(ios, nil, nil, 1.0)
          drain_self_pipe if ready&.include?(@self_r)
          handle_signals
          read_statuses(ready)
          reap_children
          check_timeouts
          maintain_worker_count unless @shutting_down
        end
      end

      private

      # トラップ内では何もせず、キューに積んでメインループを起こすだけ
      def install_traps
        SIGNALS.each do |sig|
          trap(sig) do
            @signals << sig
            @self_w.write_nonblock(".", exception: false)
          end
        end
      end

      def spawn_worker(index)
        status_r, status_w = IO.pipe
        @config.run_hooks(:before_fork, index)
        pid = fork do
          status_r.close
          @self_r.close
          @self_w.close
          Worker::Runner.new(index:, status_io: status_w, config: @config).run # 内部で exit!
        end
        status_w.close
        @workers[pid] = WorkerHandle.new(pid:, index:, status_io: status_r)
      end

      def reap_children
        loop do
          pid, status = Process.waitpid2(-1, Process::WNOHANG)
          break unless pid
          handle = @workers.delete(pid)
          handle&.close
          log_exit(handle, status)
        end
      rescue Errno::ECHILD
        nil
      end
    end
  end
end
```

`handle_signals`、`read_statuses`、`check_timeouts`、`maintain_worker_count`、`drain_self_pipe`、`log_exit` はこの骨格をもとに T2-02 以降で実装する。

---

## 6. Phase 3 作業手順（本番運用機能 v0.3）

| ID | タスク | DoD |
|---|---|---|
| T3-01 | フェーズドリスタート（`USR1`） | 「新ワーカー Ready → 旧ワーカー ドレイン」を 1 台ずつ行い、負荷中のエラーが 0 件 |
| T3-02 | ホットリエクゼク（`USR2`） | 新 master が Ready になってから旧 master が退役する。PID ファイルを更新する |
| T3-03 | ワーカーリサイクル | `max_requests` / `max_pss_mb` / `max_lifetime` + jitter。リサイクルはフェーズド方式 |
| T3-04 | 接続寿命の既定値 | `max_connection_age` 等が `server_args` に反映されることをテストで確認 |
| T3-05 | Admin HTTP サーバ | `/livez` `/readyz` `/metrics` `/status`。依存 gem なし |
| T3-06 | Health サービス | `Check` / `Watch`。ドレイン中は NOT_SERVING。ユーザー定義チェックと連動 |
| T3-07 | メトリクス集約 | パイプ経由の差分送信。`/metrics` の値が全ワーカー合計と一致 |
| T3-08 | 構造化ログ | 1 RPC 1 行。JSON / logfmt。フィールドのマスキング |
| T3-09 | TLS / mTLS | 設定で宣言でき、`peer_identity` が取れる |
| T3-10 | Kubernetes ガイドと kind テスト | マニフェスト例、sysctl、`terminationGracePeriodSeconds`。ローリングアップデートのテストに合格 |

---

## 7. Phase 4 作業手順（クライアント v0.4）

| ID | タスク | DoD |
|---|---|---|
| T4-01 | `ChannelRegistry` | `(pid, target, creds, args)` をキーに遅延生成。`Process._fork` でクリア |
| T4-02 | `Gritz::Client.define` | 生成 `Stub` のメソッドをラップ。master での呼び出しは ForkGuard 違反になる |
| T4-03 | デッドライン伝播 | `min(既定値, ctx.remaining - margin)` が適用される |
| T4-04 | メタデータ伝播 | `x-request-id` と `traceparent` が自動付与される |
| T4-05 | クライアントミドルウェアとエラー変換 | リッチ詳細を `Gritz::Errors::*` にデコードする |
| T4-06 | サービスコンフィグ | リトライ・LB が `grpc.service_config` に反映される |
| T4-07 | `gritz-otel` | サーバ・クライアントのスパン。SDK 初期化を `on_worker_boot` で自動化 |
| T4-08 | 3 段呼び出しの E2E | デッドラインとトレースが連結されることを確認 |

---

## 8. Phase 5 作業手順（Rails 統合と移行 v0.5）

| ID | タスク | DoD |
|---|---|---|
| T5-01 | `gritz-rails` の Railtie | `app/rpc` のオートロード、`eager_load!`、`RailsExecutor` |
| T5-02 | ジェネレータ | `gritz:install`（設定・binstub・initializer・`lib/protos`）、`gritz:controller` |
| T5-03 | 開発時リロード | シングルモードでのみ `reloader.wrap` |
| T5-04 | gruf 互換レイヤ | `Gruf::Controllers::Base` 相当の API とインターセプタアダプタ |
| T5-05 | 設定変換スクリプト | `Gruf.configure` から `config/gritz.rb` を生成する |
| T5-06 | Reflection | S-05 の方式で実装。既定は development のみ有効 |
| T5-07 | `examples/rails_app` | AR + 4 ワーカー。PSS 目標を満たす |
| T5-08 | 移行ガイド | 手順・よくある問題・チェックリスト |

---

## 9. Phase 6 作業手順（Async・性能・堅牢化 v0.6〜0.9）

| ID | タスク | DoD |
|---|---|---|
| T6-01 | `TransportContract` スイート | ステータス、トレーラ、デッドライン、キャンセル、メタデータ、順序、停止の各項目 |
| T6-02 | `gritz-async` | `async-grpc` ベース。`inherited_fd` 対応。契約テストに合格 |
| T6-03 | ベンチマーク基盤 | `bench/scenarios/*.yml` と実行スクリプト。結果 JSON をコミットし、前回比 10% 以上の劣化で CI を失敗させる |
| T6-04 | カオステスト | ランダム kill、`tc netem` による遅延注入、メモリ圧迫 |
| T6-05 | プロファイリングと最適化 | `stackprof` / `vernier` でホットパスを特定し、改善を ADR に記録 |
| T6-06 | ベータ運用 | 外部ユーザー 2 組織以上。フィードバックを Issue 化 |

---

## 10. Phase 7 作業手順（v1.0）

1. 公開 API を棚卸しし、`@api public` のものだけを SemVer の対象として明記する。
2. 非推奨 API を削除し、移行手順を CHANGELOG に書く。
3. ドキュメントサイトを公開する（ガイド、API リファレンス、運用ガイド、移行ガイド）。
4. セキュリティレビュー（依存関係、デフォルト設定、エラー情報の露出、Reflection の既定値）を行う。
5. サポートポリシー（対応 Ruby / grpc gem バージョン、EOL 方針）を公開する。
6. 12 章のリリース手順で v1.0.0 を公開する。

---

## 11. 共通手順

### 11.1 ブランチと PR

- `main` を保護し、トランクベースで開発する。作業ブランチは `t2-03-fork-guard` のように命名する。
- PR は 1 タスク 1 PR を原則とし、差分は 400 行程度までを目安にする。

### 11.2 PR チェックリスト

```markdown
- [ ] タスク ID と DoD を PR 本文に記載した
- [ ] テストを追加・更新した（unit / 必要なら integration）
- [ ] master で gRPC を初期化するコードを追加していない（Clean Master）
- [ ] 公開 API に YARD を書き、@api タグを付けた
- [ ] CHANGELOG の Unreleased に追記した
- [ ] 設定項目を追加した場合、既定値・検証・環境変数・ドキュメントを更新した
- [ ] シグナル / シャットダウン挙動に影響する場合、統合テストを追加した
```

### 11.3 テストの種類と実行タイミング

| 種類 | 場所 | 実行環境 | タイミング |
|---|---|---|---|
| unit | `gems/*/spec/unit` | 全 OS | 毎 PR |
| contract | `gems/*/spec/contract` | Linux | 毎 PR |
| integration（シングル） | `spec/integration/single` | 全 OS | 毎 PR |
| integration（クラスタ） | `spec/integration/cluster` | Linux のみ | 毎 PR |
| e2e（kind） | `spec/e2e` | Linux + kind | nightly |
| bench | `bench/` | 専用ランナー（固定スペック） | nightly / リリース前 |
| chaos / soak | `bench/scenarios/soak.yml` 等 | 専用ランナー | 週次 / リリース前 |

クラスタテストはフレークしやすいため、待機は固定 `sleep` ではなく `Testing::Cluster#wait_until(state:, timeout:)` で状態をポーリングする。

### 11.4 CI（GitHub Actions）

```yaml
# .github/workflows/ci.yml（抜粋）
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        # メンテナンス中の全 CRuby を並べる（"ruby" は最新安定版）
        ruby: ["3.3", "3.4", "ruby"]
        grpc: [""]               # 空 = Gemfile.lock のバージョン
        include:
          - ruby: "ruby"
            grpc: "<サポート下限のバージョン>"
          - ruby: "head"
            experimental: true
    continue-on-error: ${{ matrix.experimental == true }}
    env:
      GRPC_VERSION: ${{ matrix.grpc }}
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby }}
          bundler-cache: true
      - run: sudo sysctl -w net.ipv4.tcp_migrate_req=1
      - run: bundle exec rubocop
      - run: bundle exec rspec --tag ~e2e
      - run: bundle exec bundle-audit check --update
```

`<サポート下限のバージョン>` は Phase 0 の S-01 / S-04 の結果を踏まえて決め、サポートポリシーに記載する。

### 11.5 ADR テンプレート

```markdown
# ADR-NNN: タイトル

- ステータス: Proposed | Accepted | Rejected | Superseded by ADR-XXX
- 日付: YYYY-MM-DD
- 関連タスク: T?-??

## 背景

## 決定

## 理由

## 却下した代替案

## 影響（良い点 / 悪い点 / 移行の要否）
```

### 11.6 スパイクレポートテンプレート

```markdown
# S-0x: タイトル

- 実施日 / 実施者:
- 環境: CPU コア数, カーネル, Ruby, grpc gem, Docker の有無

## 問い

## 手順（再現可能なコマンド）

## 結果（数値・ログ・グラフ）

## 結論（合格 / 不合格、設計への影響）

## 未解決の疑問
```

### 11.7 ベンチマーク手順

1. 専用ランナー（CPU ガバナを performance に固定、他プロセスを停止）で実行する。
2. `bench/scenarios/<name>.yml` に、ワーカー数・スレッド数・`ghz` の引数・ウォームアップ時間を定義する。
3. `bin/bench <name>` で、ウォームアップ 30 秒 → 計測 60 秒 × 3 回を実行し、中央値を採用する。
4. 結果を `bench/results/<date>_<git-sha>_<name>.json` に保存し、前回との差分を PR にコメントする。

---

## 12. リリース手順

1. 全 gem の `VERSION` を同じ値に更新する（モノレポ内でバージョンを揃える）。
2. CHANGELOG の `Unreleased` を新バージョンの見出しに移す。
3. `release/vX.Y.Z` の PR を作成し、CI が緑であることを確認してマージする。
4. `git tag vX.Y.Z && git push origin vX.Y.Z` を実行する。
5. タグをトリガーに、GitHub Actions から RubyGems の Trusted Publishing で各 gem を公開する（`gritz-core` → アダプタ → `gritz` の依存順）。
6. GitHub Release を作成し、CHANGELOG の該当部分を転記する。
7. `examples/` を新バージョンで動作確認する。

RubyGems のアカウントは MFA 必須とし、gemspec に `rubygems_mfa_required = "true"` を設定する。

---

## 13. トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `grpc cannot be used before and after forking ...` | master で gRPC オブジェクトを生成している | `gritz check` で発生箇所を特定し、`Gritz::Client` か `on_worker_boot` へ移す |
| ワーカー間で負荷が偏る | 長寿命接続 | `max_connection_age` を確認する。クライアント側で `round_robin` を使う |
| ワーカー入れ替え時に `UNAVAILABLE` が出る | `SO_REUSEPORT` の accept キュー破棄 | `tcp_migrate_req=1`、フェーズドリスタートの使用、クライアントのリトライ設定 |
| macOS で 1 ワーカーにしか届かない | macOS の `SO_REUSEPORT` は分散しない | 開発は `workers 0`。マルチプロセスの検証は devcontainer で行う |
| `RESOURCE_EXHAUSTED` が増える | スレッドプール枯渇 | `threads` / `max_waiting_requests` / `workers` を調整し、遅い RPC を調査する |
| ワーカーが頻繁に KILL される | `worker_timeout` 超過（GVL を握る C 拡張、無限ループ等） | `oldest_inflight_age` のログと `gritz stats` で該当 RPC を特定する |
| 起動時に「ポート 0 は使えない」エラー | `reuseport` で `workers > 1` かつエフェメラルポート | 固定ポートを指定する。テストでは `Testing::Server`（シングルモード）を使う |
