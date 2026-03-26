#!/usr/bin/env ruby
# WEBrick開発サーバー
# 使用法: ruby web/server.rb [port] [document_root]

require 'webrick'
require 'pty'
require 'io/console'

$stdout.sync = true
$stderr.sync = true

port = (ARGV[0] || 8000).to_i
root = File.expand_path(ARGV[1] || File.dirname(__FILE__))

# 仮想シリアルペア作成
$pty_master1, pty_slave1 = PTY.open
$pty_master2, pty_slave2 = PTY.open
pty_slave1.raw!
pty_slave2.raw!

puts "=" * 50
puts "Emulator port: #{pty_slave1.path}"
puts "Synth port:    #{pty_slave2.path}"
puts "=" * 50

# エミュレーター → シンセ 中継スレッド
Thread.new do
  loop do
    begin
      data = $pty_master1.read_nonblock(256)
      $pty_master2.write(data)
    rescue IO::WaitReadable
      IO.select([$pty_master1], nil, nil, 0.01)
    rescue
      break
    end
  end
end

# wasmファイルのMIMEタイプ登録
WEBrick::HTTPUtils::DefaultMimeTypes['wasm'] = 'application/wasm'
WEBrick::HTTPUtils::DefaultMimeTypes['mjs']  = 'text/javascript'

server = WEBrick::HTTPServer.new(
  Port: port,
  DocumentRoot: root,
  Logger: WEBrick::Log.new($stdout, WEBrick::Log::INFO),
  AccessLog: [[
    $stdout,
    WEBrick::AccessLog::COMBINED_LOG_FORMAT
  ]]
)

trap('INT')  { server.shutdown }
trap('TERM') { server.shutdown }

puts "WEBrick server starting on http://localhost:#{port}/"
puts "Document root: #{root}"
server.start
