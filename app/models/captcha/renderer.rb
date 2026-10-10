require "chunky_png"

module Captcha
  # Draws a code as a distorted PNG: per-glyph rotation and vertical jitter, a
  # sine-wave warp, crossing lines and speckle noise. Only digits are needed,
  # so a 5x7 bitmap font is embedded and no system image library is required.
  class Renderer
    WIDTH = 200
    HEIGHT = 64
    SCALE = 5
    GLYPH_W = 5 * SCALE
    GLYPH_H = 7 * SCALE
    BACKGROUND = ChunkyPNG::Color.rgb(244, 243, 238)
    INKS = [ [ 28, 36, 33 ], [ 14, 107, 92 ], [ 29, 79, 145 ], [ 163, 54, 31 ] ].freeze

    GLYPHS = {
      "0" => %w[01110 10001 10011 10101 11001 10001 01110],
      "1" => %w[00100 01100 00100 00100 00100 00100 01110],
      "2" => %w[01110 10001 00001 00010 00100 01000 11111],
      "3" => %w[11110 00001 00001 01110 00001 00001 11110],
      "4" => %w[00010 00110 01010 10010 11111 00010 00010],
      "5" => %w[11111 10000 11110 00001 00001 10001 01110],
      "6" => %w[00110 01000 10000 11110 10001 10001 01110],
      "7" => %w[11111 00001 00010 00100 01000 01000 01000],
      "8" => %w[01110 10001 10001 01110 10001 10001 01110],
      "9" => %w[01110 10001 10001 01111 00001 00010 01100]
    }.freeze

    def self.png(code, random: Random.new)
      new(code, random: random).image.to_blob
    end

    def initialize(code, random: Random.new)
      @code = code.to_s
      @random = random
    end

    def image
      canvas = ChunkyPNG::Image.new(WIDTH, HEIGHT, BACKGROUND)
      speckle(canvas)
      @code.each_char.with_index { |char, index| draw_glyph(canvas, char, index) }
      strike_through(canvas)
      canvas
    end

    private

    def draw_glyph(canvas, char, index)
      bitmap = GLYPHS.fetch(char)
      ink = ink_color
      angle = @random.rand(-0.3..0.3)
      cos = Math.cos(angle)
      sin = Math.sin(angle)
      cx = 22 + (index * 34) + (GLYPH_W / 2)
      cy = (HEIGHT / 2) + @random.rand(-6..6)
      wave_amplitude = @random.rand(1.0..2.5)
      wave_length = @random.rand(9.0..13.0)
      phase = @random.rand * Math::PI * 2
      reach = 22

      ((cx - reach)..(cx + reach)).each do |px|
        ((cy - reach)..(cy + reach)).each do |py|
          next unless px.between?(0, WIDTH - 1) && py.between?(0, HEIGHT - 1)

          dx = px - cx
          dy = py - cy - (wave_amplitude * Math.sin((px / wave_length) + phase))
          sx = (dx * cos) + (dy * sin) + (GLYPH_W / 2.0)
          sy = (-dx * sin) + (dy * cos) + (GLYPH_H / 2.0)
          next unless sx >= 0 && sy >= 0 && sx < GLYPH_W && sy < GLYPH_H

          canvas[px, py] = ink if bitmap[(sy / SCALE).floor][(sx / SCALE).floor] == "1"
        end
      end
    end

    def strike_through(canvas)
      4.times do
        color = ChunkyPNG::Color.rgba(*ink_rgb, 170)
        canvas.line(
          @random.rand(0..12), @random.rand(8..(HEIGHT - 8)),
          @random.rand((WIDTH - 12)..(WIDTH - 1)), @random.rand(8..(HEIGHT - 8)),
          color
        )
      end
    end

    def speckle(canvas)
      400.times do
        shade = @random.rand(150..215)
        canvas[@random.rand(WIDTH), @random.rand(HEIGHT)] = ChunkyPNG::Color.rgb(shade, shade, shade - 6)
      end
    end

    def ink_rgb
      INKS.sample(random: @random)
    end

    def ink_color
      ChunkyPNG::Color.rgb(*ink_rgb)
    end
  end
end
