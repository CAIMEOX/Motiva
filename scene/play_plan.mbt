///|
pub(all) struct PlayConfig {
  include_start_frame : Bool
  include_end_frame : Bool
}

///|
pub fn PlayConfig::new(
  include_start_frame? : Bool = true,
  include_end_frame? : Bool = false,
) -> PlayConfig {
  { include_start_frame, include_end_frame }
}

///|
pub impl Default for PlayConfig with fn default() -> PlayConfig {
  PlayConfig::new()
}

///|
pub fn PlayConfig::image_sequence() -> PlayConfig {
  PlayConfig::new(include_start_frame=true, include_end_frame=true)
}

///|
pub(all) struct FrameTime {
  frame_index : Int
  play_time : Double
  absolute_time : Double
  dt : Double
}

///|
priv struct ScheduledAnimation {
  animation : ActiveAnimation
  start_time : Double
  end_time : Double
}

///|
pub struct PlayPlan {
  priv start_time : Double
  priv run_time : Double
  priv frame_rate : Double
  priv frame_times : Array[FrameTime]
  priv scheduled : Array[ScheduledAnimation]
}

///|
pub fn[T : IntoAnimation] Scene::compile_play_plan(
  self : Scene,
  animations : Array[T],
  config? : PlayConfig = PlayConfig::default(),
) -> PlayPlan raise SceneError {
  if animations.length() == 0 {
    raise EmptyPlay
  }
  let frame_rate = self.config.frame_rate
  if frame_rate <= 0.0 || frame_rate.is_nan() {
    raise InvalidFrameRate(frame_rate)
  }
  let active_animations = animations.map(animation => {
    ActiveAnimation::compile(self, into_animation(animation))
  })
  validate_family_animation_targets(self, active_animations)
  validate_run_times(active_animations)
  let scheduled = schedule_parallel(active_animations)
  let run_time = scheduled.fold(init=0.0, (duration, item) => {
    if item.end_time > duration {
      item.end_time
    } else {
      duration
    }
  })
  {
    start_time: self.time,
    run_time,
    frame_rate,
    frame_times: build_frame_times(
      start_time=self.time,
      run_time~,
      frame_rate~,
      config~,
    ),
    scheduled,
  }
}

///|
fn validate_run_times(
  animations : Array[ActiveAnimation],
) -> Unit raise SceneError {
  for animation in animations {
    let run_time = animation.run_time()
    if run_time <= 0.0 || run_time.is_nan() {
      raise InvalidRunTime(run_time)
    }
  }
}

///|
fn schedule_parallel(
  animations : Array[ActiveAnimation],
) -> Array[ScheduledAnimation] {
  let scheduled : Array[ScheduledAnimation] = []
  for index in 0..<animations.length() {
    match animations.get(index) {
      None => ()
      Some(animation) =>
        scheduled.push({
          animation,
          start_time: 0.0,
          end_time: animation.run_time(),
        })
    }
  }
  scheduled
}

///|
fn build_frame_times(
  start_time~ : Double,
  run_time~ : Double,
  frame_rate~ : Double,
  config~ : PlayConfig,
) -> Array[FrameTime] {
  let frames : Array[FrameTime] = []
  let step = 1.0 / frame_rate
  let mut index = 0
  let mut previous_play_time = 0.0
  while true {
    let play_time = index.to_double() * step
    if play_time >= run_time {
      break
    }
    if config.include_start_frame || index > 0 {
      let dt = if frames.length() == 0 {
        play_time
      } else {
        play_time - previous_play_time
      }
      frames.push({
        frame_index: frames.length(),
        play_time,
        absolute_time: start_time + play_time,
        dt,
      })
      previous_play_time = play_time
    }
    index += 1
  }
  if config.include_end_frame {
    let should_add_end = frames
      .last()
      .map_or(true, frame => frame.play_time < run_time)
    if should_add_end {
      let dt = frames
        .last()
        .map_or(run_time, frame => run_time - frame.play_time)
      frames.push({
        frame_index: frames.length(),
        play_time: run_time,
        absolute_time: start_time + run_time,
        dt,
      })
    }
  }
  frames
}

///|
pub fn PlayPlan::start_time(self : PlayPlan) -> Double {
  self.start_time
}

///|
pub fn PlayPlan::run_time(self : PlayPlan) -> Double {
  self.run_time
}

///|
pub fn PlayPlan::frame_rate(self : PlayPlan) -> Double {
  self.frame_rate
}

///|
pub fn PlayPlan::frame_count(self : PlayPlan) -> Int {
  self.frame_times.length()
}

///|
pub fn PlayPlan::frame_times(self : PlayPlan) -> Array[FrameTime] {
  self.frame_times.copy()
}

///|
pub fn PlayPlan::affected_ids(self : PlayPlan) -> Array[ObjectId] {
  self.scheduled.fold(init=[], (ids, item) => {
    let next = ids.copy()
    next.append(item.animation.affected_ids())
    next
  })
}

///|
pub fn PlayPlan::begin(self : PlayPlan, scene : Scene) -> Unit raise SceneError {
  for item in self.scheduled {
    scene.apply_frame_patch(item.animation.begin_patch())
  }
}

///|
pub fn PlayPlan::apply_frame(
  self : PlayPlan,
  scene : Scene,
  frame : FrameTime,
) -> Unit raise SceneError {
  for item in self.scheduled {
    if frame.play_time >= item.start_time && frame.play_time <= item.end_time {
      scene.apply_frame_patch(
        item.animation.sample_at_time(frame.play_time - item.start_time),
      )
    }
  }
  scene.time = frame.absolute_time
}

///|
pub fn PlayPlan::finish(
  self : PlayPlan,
  scene : Scene,
) -> Unit raise SceneError {
  for item in self.scheduled {
    scene.apply_frame_patch(item.animation.finish_patch())
  }
  scene.time = self.start_time + self.run_time
}
