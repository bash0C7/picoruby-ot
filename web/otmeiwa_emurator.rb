#!/usr/bin/env ruby
# otmeiwa_emurator.rb — ATOM Matrix センサーエミュレーター CLI
# 使用法: ruby web/otmeiwa_emurator.rb

require 'pty'
require 'io/console'
require 'irb'

# 仮想シリアルポート作成
$pty_master, pty_slave = PTY.open
pty_slave.raw!

puts "=" * 50
puts "Connect Chrome to: #{pty_slave.path}"
puts "=" * 50
puts ""
puts "Methods:"
puts "  emit(d: 450, ax: 0, ay: 0, az: 0)       # 1フレーム送信"
puts "  loop_emit(d: 450, ax: 0, ay: 0, az: 0)  # 送り続ける (Ctrl+C で停止)"
puts "  sweep(:d, 20, 900)                        # パラメータをスイープ"
puts ""

# 1フレーム送信
def emit(d: 450, ax: 0, ay: 0, az: 0)
  frame = "<D:#{d},AX:#{ax},AY:#{ay},AZ:#{az}>\n"
  $pty_master.write(frame)
  frame.strip
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
      from.step(to, step)    { |v| emit(**rest.merge(param => v)); sleep interval }
      to.step(from, -step)   { |v| emit(**rest.merge(param => v)); sleep interval }
    end
  end
  trap('INT', 'DEFAULT')
  puts "\nstopped"
  nil
end

binding.irb
