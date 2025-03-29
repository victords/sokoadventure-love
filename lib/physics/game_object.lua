GameObject = setmetatable({}, Sprite)
GameObject.__index = GameObject

function GameObject.new(x, y, w, h, img_path, img_gap, cols, rows, mass, max_speed)
  local self = Sprite.new(x, y, img_path, cols, rows)
  setmetatable(self, GameObject)
  self.w = w
  self.h = h
  self.img_gap = img_gap or Vector.new()

  self.mass = mass or 1
  self.max_speed = max_speed or Vector.new(15, 15)
  self.speed = Vector.new()
  self.stored_forces = Vector.new()

  return self
end

function GameObject:draw(scale_x, scale_y, color, angle, flip, scale_img_gap)
  scale_x = scale_x or 1
  scale_y = scale_y or 1
  if scale_img_gap == nil then scale_img_gap = true end
  local img_gap_scale_x = scale_img_gap and scale_x or 1
  local img_gap_scale_y = scale_img_gap and scale_y or 1
  local origin_x = 0.5 * (self.w / scale_x) - self.img_gap.x
  local origin_y = 0.5 * (self.h / scale_y) - self.img_gap.y
  local x = self.x + img_gap_scale_x * self.img_gap.x + scale_x * origin_x
  local y = self.y + img_gap_scale_y * self.img_gap.y + scale_y * origin_y
  local scale_x_factor = flip == "horiz" and -1 or 1
  local scale_y_factor = flip == "vert" and -1 or 1
  if color then love.graphics.setColor(color) end
  love.graphics.draw(self.img, self.quads[self.img_index], x, y, angle, scale_x_factor * scale_x, scale_y_factor * scale_y, origin_x, origin_y)
  if color then love.graphics.setColor(1, 1, 1) end
end

function GameObject:bounds()
  return Rectangle.new(self.x, self.y, self.w, self.h)
end

function GameObject:move(forces, obst, ramps, set_speed)
  local speed = self.speed
  if set_speed then
    speed.x = forces.x
    speed.y = forces.y
  else
    forces = forces + Physics.gravity + self.stored_forces
    self.stored_forces = Vector.new()

    if (forces.x < 0 and self.left) or (forces.x > 0 and self.right) then forces.x = 0 end
    if (forces.y < 0 and self.top) or (forces.y > 0 and self.bottom) then forces.y = 0 end

    if getmetatable(self.bottom) == Ramp then
      local threshold = Physics.ramp_slip_threshold
      if self.bottom.ratio > threshold then
        forces.x = forces.x + (self.bottom.left and -1 or 1) * (self.bottom.ratio - threshold) * Physics.ramp_slip_force / threshold
      elseif forces.x > 0 and self.bottom.left or forces.x < 0 and not self.bottom.left then
        forces.x = forces.x * self.bottom.factor
      end
    end

    self.speed = speed + (forces / self.mass)
    speed = self.speed
  end

  if math.abs(speed.x) < Physics.min_speed.x then speed.x = 0 end
  if math.abs(speed.y) < Physics.min_speed.y then speed.y = 0 end
  if math.abs(speed.x) > self.max_speed.x then speed.x = (speed.x < 0 and -1 or 1) * self.max_speed.x end
  if math.abs(speed.y) > self.max_speed.y then speed.y = (speed.y < 0 and -1 or 1) * self.max_speed.y end
  self.prev_speed = utils.clone(speed)

  if speed.x == 0 and speed.y == 0 then return end

  local x = speed.x < 0 and self.x + speed.x or self.x
  local y = speed.y < 0 and self.y + speed.y or self.y
  local w = self.w + math.abs(speed.x)
  local h = self.h + math.abs(speed.y)
  local move_bounds = Rectangle.new(x, y, w, h)
  local coll_list = {}
  for _, o in ipairs(obst) do
    if o ~= self and move_bounds:intersect(o:bounds()) then table.insert(coll_list, o) end
  end
  for _, r in ipairs(ramps) do
    r:check_can_collide(move_bounds)
  end

  if #coll_list > 0 then
    local up = speed.y < 0
    local rt = speed.x > 0
    local dn = speed.y > 0
    local lf = speed.x < 0
    if speed.x == 0 or speed.y == 0 then
      -- orthogonal movement
      if rt then
        local x_lim = self:find_right_limit(coll_list)
        if self.x + self.w + speed.x > x_lim then
          self.x = x_lim - self.w
          speed.x = 0
        end
      elseif lf then
        local x_lim = self:find_left_limit(coll_list)
        if self.x + speed.x < x_lim then
          self.x = x_lim
          speed.x = 0
        end
      elseif dn then
        local y_lim = self:find_down_limit(coll_list)
        if self.y + self.h + speed.y > y_lim then
          self.y = y_lim - self.h
          speed.y = 0
        end
      else -- up
        local y_lim = self:find_up_limit(coll_list)
        if self.y + speed.y < y_lim then
          self.y = y_lim
          speed.y = 0
        end
      end
    else
      -- diagonal movement
      x_aim = self.x + speed.x + (rt and self.w or 0)
      x_lim_def = {x_aim, nil}
      y_aim = self.y + speed.y + (dn and self.h or 0)
      y_lim_def = {y_aim, nil}
      for _, c in ipairs(coll_list) do
        self:find_limits(c, x_aim, y_aim, x_lim_def, y_lim_def, up, rt, dn, lf)
      end

      if x_lim_def[1] ~= x_aim and y_lim_def[1] ~= y_aim then
        x_time = (x_lim_def[1] - self.x - (lf and 0 or self.w)) / speed.x
        y_time = (y_lim_def[1] - self.y - (up and 0 or self.h)) / speed.y
        if x_time < y_time then
          self:stop_at_x(x_lim_def[1], lf)
          move_bounds = Rectangle.new(self.x, up and self.y + speed.y or self.y, self.w, self.h + math.abs(speed.y))
          if move_bounds:intersect(y_lim_def[2]:bounds()) then self:stop_at_y(y_lim_def[1], up) end
        else
          self:stop_at_y(y_lim_def[1], up)
          move_bounds = Rectangle.new(lf and self.x + speed.x or self.x, self.y, self.w + math.abs(speed.x), self.h)
          if move_bounds:intersect(x_lim_def[2]:bounds()) then self:stop_at_x(x_lim_def[1], lf) end
        end
      elseif x_lim_def[1] ~= x_aim then
        self:stop_at_x(x_lim_def[1], lf)
      elseif y_lim_def[1] ~= y_aim then
        self:stop_at_y(y_lim_def[1], up)
      end
    end
  end
  self.x = self.x + speed.x
  self.y = self.y + speed.y

  for _, r in ipairs(ramps) do
    r:check_intersection(self)
  end
  self:check_contact(obst, ramps)
end

function GameObject:move_carrying(arg, scalar_speed, carried_objs, obstacles, ramps, ignore_collision)
  local speed = self.speed
  local x_aim = nil
  local y_aim = nil
  if scalar_speed then
    local x_d = arg.x - self.x
    local y_d = arg.y - self.y
    distance = math.sqrt(x_d^2 + y_d^2)

    if distance == 0 then
      speed.x = 0
      speed.y = 0
      return
    end

    speed.x = x_d * scalar_speed / distance
    speed.y = y_d * scalar_speed / distance
    x_aim = self.x + speed.x
    y_aim = self.y + speed.y
  else
    x_aim = self.x + speed.x + Physics.gravity.x + arg.x
    y_aim = self.y + speed.y + Physics.gravity.y + arg.y
  end

  local passengers = {}
  for _, o in ipairs(carried_objs) do
    if self.x + self.w > o.x and o.x + o.w > self.x then
      local foot = o.y + o.h
      if utils.approx_equal(foot, self.y) or (speed.y < 0 and foot < self.y and foot > y_aim) then
        table.insert(passengers, o)
      end
    end
  end

  local prev_x = self.x
  local prev_y = self.y
  if scalar_speed then
    if speed.x > 0 and x_aim >= arg.x or speed.x < 0 and x_aim <= arg.x then
      self.x = arg.x
      speed.x = 0
    else
      self.x = x_aim
    end
    if speed.y > 0 and y_aim >= arg.y or speed.y < 0 and y_aim <= arg.y then
      self.y = arg.y
      speed.y = 0
    else
      self.y = y_aim
    end
  else
    self:move(arg, ignore_collision and {} or obstacles, ignore_collision and {} or ramps)
  end

  local forces = Vector.new(self.x - prev_x, self.y - prev_y)
  local prev_g = utils.clone(Physics.gravity)
  Physics.gravity.x = 0
  Physics.gravity.y = 0
  for _, p in ipairs(passengers) do
    if getmetatable(p).move then
      local prev_speed = utils.clone(p.speed)
      local prev_forces = utils.clone(p.stored_forces)
      local prev_bottom = p.bottom
      p.speed.x = 0
      p.speed.y = 0
      p.stored_forces.x = 0
      p.stored_forces.y = 0
      p.bottom = nil
      p:move(forces * p.mass, obstacles, ramps)
      p.speed = prev_speed
      p.stored_forces = prev_forces
      p.bottom = prev_bottom
    else
      p.x = p.x + forces.x
      p.y = p.y + forces.y
    end
  end
  Physics.gravity = prev_g
end

function GameObject:move_free(aim, scalar_speed)
  local speed = self.speed
  if type(aim) == "number" then
    local rads = aim * math.pi / 180
    speed.x = scalar_speed * math.cos(rads)
    speed.y = scalar_speed * math.sin(rads)
    self.x = self.x + speed.x
    self.y = self.y + speed.y
  else -- aim is a Vector
    local x_d = aim.x - self.x
    local y_d = aim.y - self.y
    local distance = math.sqrt(x_d^2 + y_d^2)

    if distance == 0 then
      speed.x = 0
      speed.y = 0
      return
    end

    speed.x = x_d * scalar_speed / distance
    speed.y = y_d * scalar_speed / distance

    if (speed.x < 0 and self.x + speed.x <= aim.x) or (speed.x >= 0 and self.x + speed.x >= aim.x) then
      self.x = aim.x
      speed.x = 0
    else
      self.x = self.x + speed.x
    end

    if (speed.y < 0 and self.y + speed.y <= aim.y) or (speed.y >= 0 and self.y + speed.y >= aim.y) then
      self.y = aim.y
      speed.y = 0
    else
      self.y = self.y + speed.y
    end
  end
end

function GameObject:cycle(points, scalar_speed, carried_objs, obstacles, ramps, stop_time)
  stop_time = stop_time or 0
  if not self.cycle_setup then
    self.cur_point = self.cur_point or 1
    if carried_objs then
      obstacles = obstacles or {}
      ramps = ramps or {}
      self:move_carrying(points[self.cur_point], scalar_speed, carried_objs, obstacles, ramps)
    else
      self:move_free(points[self.cur_point], scalar_speed)
    end
  end
  if self.speed.x == 0 and self.speed.y == 0 then
    if not self.cycle_setup then
      self.cycle_timer = 0
      self.cycle_setup = true
    end
    if self.cycle_timer >= stop_time then
      if self.cur_point == #points then
        self.cur_point = 1
      else
        self.cur_point = self.cur_point + 1
      end
      self.cycle_setup = false
    else
      self.cycle_timer = self.cycle_timer + 1
    end
  end
end

-- private
function GameObject:check_contact(obst, ramps)
  local prev_bottom = self.bottom
  self.top = nil; self.bottom = nil; self.left = nil; self.right = nil
  for _, o in ipairs(obst) do
    local x2 = self.x + self.w
    local y2 = self.y + self.h
    local x2o = o.x + o.w
    local y2o = o.y + o.h
    if not o.passable and utils.approx_equal(x2, o.x) and y2 > o.y and self.y < y2o then self.right = o end
    if not o.passable and utils.approx_equal(self.x, x2o) and y2 > o.y and self.y < y2o then self.left = o end
    if utils.approx_equal(y2, o.y) and x2 > o.x and self.x < x2o then self.bottom = o end
    if not o.passable and utils.approx_equal(self.y, y2o) and x2 > o.x and self.x < x2o then self.top = o end
  end
  if self.bottom == nil then
    for _, r in ipairs(ramps) do
      if r:contact(self) then
        self.bottom = r
        break
      end
    end
    if self.bottom == nil then
      for _, r in ipairs(ramps) do
        if r == prev_bottom and
           self.x + self.w > r.x and
           r.x + r.w > self.x and
           math.abs(self.prev_speed.x) <= Physics.ramp_contact_threshold and
           self.prev_speed.y >= 0 then
          self.y = r:get_y(self)
          self.bottom = r
          break
        end
      end
    end
  end
end

function GameObject:find_right_limit(coll_list)
  local limit = self.x + self.w + self.speed.x
  for _, c in ipairs(coll_list) do
    if not c.passable and c.x < limit then limit = c.x end
  end
  return limit
end

function GameObject:find_left_limit(coll_list)
  local limit = self.x + self.speed.x
  for _, c in ipairs(coll_list) do
    if not c.passable and c.x + c.w > limit then limit = c.x + c.w end
  end
  return limit
end

function GameObject:find_down_limit(coll_list)
  local limit = self.y + self.h + self.speed.y
  for _, c in ipairs(coll_list) do
    if c.y < limit and (not c.passable or c.y >= self.y + self.h) then limit = c.y end
  end
  return limit
end

function GameObject:find_up_limit(coll_list)
  local limit = self.y + self.speed.y
  for _, c in ipairs(coll_list) do
    if not c.passable and c.y + c.h > limit then limit = c.y + c.h end
  end
  return limit
end

function GameObject:find_limits(obj, x_aim, y_aim, x_lim_def, y_lim_def, up, rt, dn, lf)
  local x_lim = obj.x + obj.w
  if obj.passable then
    x_lim = x_aim
  elseif rt then
    x_lim = obj.x
  end

  local y_lim = obj.y + obj.h
  if dn then
    y_lim = obj.y
  elseif obj.passable then
    y_lim = y_aim
  end

  local x_v = x_lim_def[1]
  local y_v = y_lim_def[1]
  if obj.passable then
    if dn and self.y + self.h <= y_lim and y_lim < y_v then
      y_lim_def[1] = y_lim
      y_lim_def[2] = obj
    end
  elseif (rt and self.x + self.w > x_lim) or (lf and self.x < x_lim) then
    -- Can't limit by x, will limit by y
    if (dn and y_lim < y_v) or (up and y_lim > y_v) then
      y_lim_def[1] = y_lim
      y_lim_def[2] = obj
    end
  elseif (dn and self.y + self.h > y_lim) or (up and self.y < y_lim) then
    -- Can't limit by y, will limit by x
    if (rt and x_lim < x_v) or (lf and x_lim > x_v) then
      x_lim_def[1] = x_lim
      x_lim_def[2] = obj
    end
  else
    local x_time = (x_lim - self.x - (lf and 0 or self.w)) / self.speed.x
    local y_time = (y_lim - self.y - (up and 0 or self.h)) / self.speed.y
    if x_time > y_time then
      -- Will limit by x
      if (rt and x_lim < x_v) or (lf and x_lim > x_v) then
        x_lim_def[1] = x_lim
        x_lim_def[2] = obj
      end
    elseif (dn and y_lim < y_v) or (up and y_lim > y_v) then
      y_lim_def[1] = y_lim
      y_lim_def[2] = obj
    end
  end
end

function GameObject:stop_at_x(x, moving_left)
  self.speed.x = 0
  self.x = moving_left and x or x - self.w
end

function GameObject:stop_at_y(y, moving_up)
  self.speed.y = 0
  self.y = moving_up and y or y - self.h
end
