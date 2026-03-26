#!/usr/bin/env ruby
# otmeiwa_emurator.rb — ATOM Matrix センサーエミュレーター CLI
# 使用法: ruby web/otmeiwa_emurator.rb

require 'webrick'
require 'irb'

$current_frame = "<D:450,AX:0,AY:0,AZ:0>"

# フレーム配信 HTTP サーバー (port 9999)
Thread.new do
  srv = WEBrick::HTTPServer.new(
    Port: 9999,
    Logger: WEBrick::Log.new(IO::NULL),
    AccessLog: []
  )
  srv.mount_proc('/frame') do |_req, res|
    res['Content-Type'] = 'text/plain'
    res['Access-Control-Allow-Origin'] = '*'
    res.body = $current_frame
  end
  trap('INT') { srv.shutdown }
  srv.start
end

sleep 0.3  # サーバー起動待ち

puts "=" * 50
puts "Emulator ready: http://localhost:9999/frame"
puts "index.html を開くと自動接続します"
puts "=" * 50
puts ""
puts "Methods:"
puts "  emit(d: 450, ax: 0, ay: 0, az: 0)       # 1フレーム送信"
puts "  loop_emit(d: 450, ax: 0, ay: 0, az: 0)  # 送り続ける (Ctrl+C で停止)"
puts "  sweep(:d, 20, 900)                        # パラメータをスイープ"
puts ""

# 1フレーム送信
def emit(d: 450, ax: 0, ay: 0, az: 0)
  $current_frame = "<D:#{d},AX:#{ax},AY:#{ay},AZ:#{az}>"
end

# 送り続ける (Ctrl+C で停止)
def loop_emit(d: 450, ax: 0, ay: 0, az: 0)
  trap('INT') { throw :stop }
  catch(:stop) do
    loop do
      emit(d: d, ax: ax, ay: ay, az: az)
      sleep 0.05
    end
  end
  trap('INT', 'DEFAULT')
  puts "\nstopped"
  nil
end

# パラメータをスイープしながら送り続ける (Ctrl+C で停止)
def sweep(param, from, to, step: 20, interval: 0.05, **rest)
  trap('INT') { throw :stop }
  catch(:stop) do
    loop do
      from.step(to, step)  { |v| emit(**rest.merge(param => v)); sleep interval }
      to.step(from, -step) { |v| emit(**rest.merge(param => v)); sleep interval }
    end
  end
  trap('INT', 'DEFAULT')
  puts "\nstopped"
  nil
end

binding.irb
