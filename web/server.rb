#!/usr/bin/env ruby
# WEBrick開発サーバー
# 使用法: ruby web/server.rb [port] [document_root]

require 'webrick'

port = (ARGV[0] || 8000).to_i
root = File.expand_path(ARGV[1] || File.dirname(__FILE__))

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
