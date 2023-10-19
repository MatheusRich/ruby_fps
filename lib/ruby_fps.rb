# frozen_string_literal: true

require "io/console"

class RubyFps
  def self.run
    new.run
  end

  def run
    IO.console.clear_screen
    system("tput civis") # hide cursor

    # textures
    wall_texture = "#"
    wall_light_shade = "█"
    wall_medium_shade = "▓"
    wall_dark_shade = "▒"
    wall_darker_shade = "░"
    ceiling_texture = " "

    # screen
    screen_width = 120
    screen_height = 40
    screen_buffer = Array.new(screen_width * screen_height)

    # player
    player_x = 8.0
    player_y = 8.0
    player_angle = 0.0
    field_of_view = 3.14159 / 4.0
    max_depth = 16.0

    # map
    map_height = 16
    map_width = 16
    map = "#########......." \
          "#..............." \
          "#.......########" \
          "#..............#" \
          "#......##......#" \
          "#......##......#" \
          "#..............#" \
          "###............#" \
          "##.............#" \
          "#......####..###" \
          "#......#.......#" \
          "#......#.......#" \
          "#..............#" \
          "#......#########" \
          "#..............#" \
          "################"

    previous_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    current_time = nil

    loop do
      current_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      elapsed_time = current_time - previous_time
      previous_time = current_time

      # reads a single byte from stdin without blocking
      key = $stdin.raw do |io|
        io.read_nonblock(1)
      rescue IO::WaitReadable
        nil
      end

      case key
      when "a"
        player_angle -= 10.0 * elapsed_time
      when "d"
        player_angle += 10.0 * elapsed_time
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
        wall_shade = if distance_to_wall <= max_depth / 4.0
          wall_light_shade
        elsif distance_to_wall < max_depth / 3.0
          wall_medium_shade
        elsif distance_to_wall < max_depth / 2.0
          wall_dark_shade
        elsif distance_to_wall < max_depth
          wall_darker_shade
        else
          " "
        end

        (0...screen_height).each do |y|
          screen_buffer[y * screen_width + x] = if y < ceiling
            ceiling_texture
          elsif y > ceiling && y <= floor
            wall_shade
          else
            # floor shade based on distance
            b = 1.0 - ((y - screen_height / 2.0) / (screen_height / 2.0))

            if b < 0.25
              "#"
            elsif b < 0.5
              "x"
            elsif b < 0.75
              "."
            elsif b < 0.9
              "-"
            else
              " "
            end

          end
        end
      end

      IO.console.cursor = [0, 0]
      IO.console.puts screen_buffer.each_slice(screen_width).map(&:join).join("\n")
      IO.console.puts "FPS: #{1.0 / elapsed_time}"
      IO.console.puts "X: #{player_x}, Y: #{player_y}, Angle: #{player_angle}"
    end
  ensure
    system("tput cnorm") # show cursor
  end
end