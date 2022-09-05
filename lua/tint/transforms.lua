local colors = require("tint.colors")

local transforms = {}

--- Transform a color given a change in tint and saturation
---
---@param hl_group_info table Table containing information about the highlight group being transformed
---@param hex string The hex color to transform.
---@param xforms table A table of functions used to transform the input hex color
---@return string The hex representation color transformed by the configured values
transforms.transform_color = function(hl_group_info, hex, xforms)
  local r, g, b = colors.hex_to_rgb(hex)

  for _, x in ipairs(xforms) do
    r, g, b = x(r, g, b, hl_group_info)
  end

  return colors.rgb_to_hex(r, g, b)
end

--- Generate function to saturate a color by the specified amount
---
---@param amt number The amount to saturate the color by
transforms.saturate = function(amt)
  return function(r, g, b, _)
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
transforms.tint = function(amt)
  return function(r, g, b, _)
    return r + amt, g + amt, b + amt
  end
end

--- Generate function to tint a color, but keep it far enough away from some other color, e.g. `Normal`
---
---@param tint number The amount to tint by
---@param compare string The hex color to not get too close to
---@param threshold number The threshold from which to stay away from the target color
transforms.tint_with_threshold = function(tint, compare, threshold)
  if not string.match(compare, "#%x%x%x%x%x%x") then
    error("'compare' value passed to `tint.transforms.tint_with_threshold' not a valid hex color, must be '#XXXXXX'")
  end

  threshold = math.abs(threshold)

  return function(r, g, b, _)
    -- Local copy, otherwise we alter it for the first color and no others
    local amt = tint

    local r1, g1, b1 = colors.hex_to_rgb(compare)
    local r2, g2, b2 = r, g, b

    while math.abs(amt) > 1 do
      r2, g2, b2 = r + amt, g + amt, b + amt

      if colors.within_threshold({ r = r2, g = g2, b = b2 }, { r = r1, g = g1, b = b1 }, threshold) then
        break
      end

      amt = math.ceil(amt / 2)
    end

    return r2, g2, b2
  end
end

return transforms
