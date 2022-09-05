local colors = {}

--- Format a decimal as a 6-digit hex value
---
---@param val number Number to format as 6-digit hex
---@return string The color represented as 6-digit hex
colors.get_hex = function(val)
  return string.format("%06x", val)
end

--- Clamp a value between 0 and 255
---
---@param component number A number to bound within [0, 255]
---@return string The color clamped between 0 and 255
colors.clamp = function(component)
  return math.min(math.max(component, 0), 255)
end

--- Transform RGB values to hex
---
---@param r number The `red` component of a color
---@param g number The `green` component of a color
---@param b number The `blue` component of a color
---@return string The RGB value formatted as a hex color string (including the leading `#`)
colors.rgb_to_hex = function(r, g, b)
  return string.format("#%06x", colors.clamp(r) * 0x10000 + colors.clamp(g) * 0x100 + colors.clamp(b))
end

--- Transform RGB values to hex
---
---@param hex string Hex representation of a color
---@return any A "tuple" of R, G and B number values
colors.hex_to_rgb = function(hex)
  if string.find(hex, "^#") then
    hex = string.sub(hex, 2)
  end

  local base16 = tonumber(hex, 16)
  return math.floor(base16 / 0x10000), (math.floor(base16 / 0x100) % 0x100), (base16 % 0x100)
end

--- Determine if one color is too close in proximity to another
---
---@param src table A table with `r`, `g` and `b` keys for a given color, representing the color in question
---@param other table A table with `r`, `g` and `b` keys for a given color to compare against
---@param threshold number The threshold that determines if the colors are too close
colors.within_threshold = function(src, other, threshold)
  threshold = threshold or 50

  local r = math.abs(other.r - src.r)
  local g = math.abs(other.g - src.g)
  local b = math.abs(other.b - src.b)

  return (r + g + b) >= threshold
end

return colors
