# frozen_string_literal: true

require "io/console"

class RubyFps
  def self.run
    new.run
  end

  def run
    IO.console.clear_screen
    system("tput civis") # hide cursor
    IO.console.raw!

    # screen
    screen_width = 120
    screen_height = 40
    screen_buffer = Array.new(screen_width * screen_height)
    cached_screen_buffer = nil
    fps = 30.0

    # textures
    wall_texture = "#"
    light_shade = "█"
    medium_shade = "▓"
    dark_shade = "▒"
    darker_shade = "░"
    sky_map = Array.new(screen_width * screen_height) { |i|
      c = ((rand(0..100) == 1) ? "·" : " ")
      on_black(white(c))
    }

    # player
    player_x = 2.0
    player_y = 2.0
    player_angle = 0
    field_of_view = 3.14159 / 4.0

    map = []
    map << "################"
    map << "#..............#"
    map << "#..............#"
    map << "#.....#........#"
    map << "#.....#........#"
    map << "#.....#........#"
    map << "#.....#........#"
    map << "#.....#........#"
    map << "#######........#"
    map << "#..............#"
    map << "#..............#"
    map << "#.........#....#"
    map << "#.........#....#"
    map << "#.........#....#"
    map << "#.........######"
    map << "#..............#"
    map << "#..............#"
    map << "################"
    map_height = map.size
    map_width = map.first.size
    max_depth = 16
    map = map.join

    previous_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    current_time = nil

    loop do
      current_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      elapsed_time = current_time - previous_time
      previous_time = current_time

      # reads a single byte from stdin without blocking
      key = begin
        IO.console.read_nonblock(1)
      rescue IO::WaitReadable
        nil
      end

      case key
      when "a"
        player_angle -= (2.0 * elapsed_time)
        player_angle %= 2 * Math::PI
      when "d"
        player_angle += (2.0 * elapsed_time)
        player_angle %= 2 * Math::PI
      when "w"
        player_x += Math.sin(player_angle) * 5.0 * elapsed_time
        player_y += Math.cos(player_angle) * 5.0 * elapsed_time
      when "s"
        player_x -= Math.sin(player_angle) * 5.0 * elapsed_time
        player_y -= Math.cos(player_angle) * 5.0 * elapsed_time
      when "q"
        break
      end

      (0...screen_width).each do |x|
        # for each column, calculate the projected ray angle into world space
        ray_angle = (player_angle - field_of_view / 2.0) + (x / screen_width.to_f) * field_of_view
        distance_to_wall = 0.0

        eye_x = Math.sin(ray_angle)
        eye_y = Math.cos(ray_angle)

        hit_wall = false
        until hit_wall || distance_to_wall >= max_depth
          distance_to_wall += 0.1

          ray_x = (player_x + eye_x * distance_to_wall).floor
          ray_y = (player_y + eye_y * distance_to_wall).floor

          # check if ray is out of bounds
          if ray_x < 0 || ray_x >= map_width || ray_y < 0 || ray_y >= map_height
            hit_wall = true
            distance_to_wall = max_depth
          elsif map[ray_y * map_width + ray_x] == wall_texture # check if ray has hit wall
            hit_wall = true
          end
        end

        ceiling = (screen_height / 2.0) - screen_height / distance_to_wall
        floor = screen_height - ceiling
        shade = if distance_to_wall <= max_depth / 4.0
          light_shade
        elsif distance_to_wall < max_depth / 3.0
          medium_shade
        elsif distance_to_wall < max_depth / 2.0
          dark_shade
        elsif distance_to_wall < max_depth
          darker_shade
        else
          " "
        end

        (0...screen_height).each do |y|
          pixel = if y < ceiling
            sky_map[y * screen_width + x]
          elsif y > ceiling && y <= floor
            red(on_black(shade))
          else
            # floor shade based on distance
            b = 1.0 - ((y - screen_height / 2.0) / (screen_height / 2.0))

            floor_shade = if b < 0.25 # very close to the player
              black(on_dark_gray(darker_shade))
            elsif b < 0.5
              on_black(darker_shade)
            elsif b < 0.75
              black(on_dark_gray(dark_shade))
            else
              black(on_dark_gray(medium_shade))
            end

            floor_shade
          end

          screen_buffer[y * screen_width + x] = pixel
        end
      end

      # render minimap
      (0...map_width).each do |x|
        (0...map_height).each do |y|
          screen_buffer[y * screen_width + x] = white(on_black(map[y * map_width + x]))
        end
      end

      # Convert angle to degrees if it's in radians
      angle = player_angle * 180 / Math::PI

      # Determine the direction based on the angle
      player_char = case angle
      when 0...22.5, 337.5..360
        "▼"
      when 22.5...67.5
        "◢"
      when 67.5...112.5
        "▶"
      when 112.5...157.5
        "◥"
      when 157.5...202.5
        "▲"
      when 202.5...247.5
        "◤"
      when 247.5...292.5
        "◀"
      when 292.5...337.5
        "◣"
      end

      screen_buffer[(player_y.to_i * screen_width + player_x.to_i)] = red(on_black(player_char))

      # avoid rendering if nothing changed
      if screen_buffer != cached_screen_buffer
        IO.console.cooked do |io|
          IO.console.cursor = [0, 0]
          IO.console.puts screen_buffer.each_slice(screen_width).map(&:join).join("\n")
        end
        cached_screen_buffer = screen_buffer.dup
      else
        IO.console.cursor = [screen_height, 0]
      end
      sleep_time = (1 / fps) - elapsed_time
      sleep(sleep_time) if sleep_time > 0
      IO.console.cooked do |io|
        io.puts "FPS: #{1.0 / elapsed_time}"
        io.puts "X: #{player_x} | Y: #{player_y} | Angle: #{player_angle}"
      end
    end
  ensure
    system("tput cnorm") # show cursor
    IO.console.cooked!
  end

  def white(string)
    "\e[37m#{string}\e[0m"
  end

  def black(string)
    "\e[30m#{string}\e[0m"
  end

  def red(string)
    "\e[31m#{string}\e[0m"
  end

  def on_black(string)
    "\e[40m#{string}\e[0m"
  end

  def on_dark_gray(string)
    "\e[100m#{string}\e[0m"
  end
end
