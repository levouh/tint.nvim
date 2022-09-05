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

--- Generate function to saturate a color by the specified amount
---
---@param amt number The amount to saturate the color by
colors.saturate = function(amt)
  return function(r, g, b)
    if amt ~= 1 then
      local rec601_luma = 0.299 * r + 0.587 * g + 0.114 * b

      r = math.floor(r * amt + rec601_luma * (1 - amt))
      g = math.floor(g * amt + rec601_luma * (1 - amt))
      b = math.floor(b * amt + rec601_luma * (1 - amt))
    end

    return r, g, b
  end
end

--- Generate function to lighten or darken a color by the specified amount
---
---@param amt number The amount to lighten or darken the color by
colors.tint = function(amt)
  return function(r, g, b)
    return r + amt, g + amt, b + amt
  end
end

--- Transform a color given a change in tint and saturation
---
---@param hex string The hex color to transform.
---@param transforms table A table of functions used to transform the input hex color
---@return string The hex representation color transformed by the configured values
colors.transform_color = function(hex, transforms)
  local r, g, b = colors.hex_to_rgb(hex)

  for _, transform in ipairs(transforms) do
    r, g, b = transform(r, g, b)
  end

  return colors.rgb_to_hex(r, g, b)
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

return colors
