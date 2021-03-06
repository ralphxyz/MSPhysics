module MSPhysics

  # @since 1.0.0
  class Simulation

    @@instance ||= nil

    class << self

      # Get {Simulation} instance.
      # @return [Simulation, nil]
      def instance
        @@instance
      end

      # Determine if simulation is running.
      # @return [Boolean]
      def is_active?
        @@instance ? true : false
      end

      # Start simulation.
      # @return [Boolean] success
      def start
        return false if is_active?
        MSPhysics::Replay.reset
        Sketchup.active_model.select_tool(Simulation.new)
        true
      end

      # Reset simulation.
      # @return [Boolean] success
      def reset
        return false unless is_active?
        Sketchup.active_model.select_tool nil
        true
      end

    end # class << self

    def initialize
      default = MSPhysics::DEFAULT_SIMULATION_SETTINGS
      @world = nil
      @update_rate = default[:update_rate]
      @update_timestep = default[:update_timestep]
      @mode = 0
      @frame = 0
      @fps = 0
      @time_info = { :start => 0, :end => 0, :last => 0, :sim => 0, :total => 0 }
      @fps_info = { :update_rate => 10, :last => 0, :change => 0 }
      @selected_page = nil
      @camera = { :original => nil, :follow => nil, :target => nil, :offset => nil }
      @rendering_options = {}
      @shadow_info = {}
      @layers = {}
      @cursor_id = MSPhysics::CURSORS[:hand]
      @original_cursor_id = @cursor_id
      @cursor_pos = [0,0]
      @interactive_note = "Interactive mode: Click and drag a physics body to move. Hold SHIFT while dragging to lift."
      @game_note = "Game mode: All control over bodies and camera via mouse is restricted as the mouse is reserved for gaming."
      @general_note = "PAUSE - toggle play  ESC - reset"
      @paused = false
      @pause_updated = false
      @suspended = false
      @mouse_over = true
      @menu_entered = false
      @menu_entered2 = false
      @update_timer = nil
      @ip1 = Sketchup::InputPoint.new
      @ip = Sketchup::InputPoint.new
      @picked = []
      @clicked = nil
      @error = nil
      @saved_transformations = {}
      @lltext = { :ent => nil, :mat => nil, :log => [], :limit => 20 }
      @dntext = { :ent => nil, :mat => nil }
      @emitted_bodies = {}
      @created_entities = []
      @bb = Geom::BoundingBox.new
      @draw_queue = []
      @points_queue = []
      @ccm = false
      @show_bodies = true
      @hidden_entities = []
      @timers_started = false
      @update_wait = 0
      @contact_points = {
        :show           => false,
        :point_size     => 3,
        :point_style    => 2,
        :point_color    => Sketchup::Color.new(153, 68, 95)
      }
      @contact_forces = {
        :show           => false,
        :line_width     => 1,
        :line_stipple   => '',
        :line_color     => Sketchup::Color.new(100, 160, 255)
      }
      @aabb = {
        :show           => false,
        :line_width     => 1,
        :line_stipple   => '',
        :line_color     => Sketchup::Color.new(68, 53, 165)
      }
      @collision_wireframe = {
        :show           => false,
        :line_width     => 1,
        :line_stipple   => '',
        :active         => Sketchup::Color.new(221, 38, 165),
        :sleeping       => Sketchup::Color.new(255, 255, 100),
        :show_edges     => nil,
        :show_profiles  => nil
      }
      @axes = {
        :show           => false,
        :line_width     => 2,
        :line_stipple   => '',
        :size           => 20,
        :xaxis          => Sketchup::Color.new(255, 0, 0),
        :yaxis          => Sketchup::Color.new(0, 255, 0),
        :zaxis          => Sketchup::Color.new(0, 0, 255)
      }
      @pick_and_drag = {
        :line_width     => 2,
        :line_stipple   => '_',
        :line_color     => Sketchup::Color.new(60, 60, 60),
        :point_size     => 10,
        :point_style    => 4,
        :point_color    => Sketchup::Color.new(4, 4, 4),
        :vline_width    => 2,
        :vline_stipple  => '',
        :vline_color    => Sketchup::Color.new(0, 40, 255)
      }
      @controller_context = MSPhysics::Controller.new
      @thrusters = {}
      @emitters = {}
      @buoyancy_planes = {}
      @controlled_joints = {}
      @scene_data1 = nil
      @scene_data2 = nil
      @scene_selected_time = nil
      @scene_transition_time = nil
      @cc_bodies = []
      @particles = []
      @particle_def2d = {}
      @particle_def3d = {}
      @particles_visible = true
      @curves = {}
      @undo_on_reset = false
      @joystick_data = {}
      @joybutton_data = {}
      @joypad_data = 0
      @@instance = self
    end

    # @!attribute [r] world
    #   Get simulation world.
    #   @return [World]

    # @!attribute [r] frame
    #   Get simulation frame.
    #   @return [Fixnum]

    # @!attribute [r] fps
    #   # Get simulation update rate in frames per second.
    #   @return [Fixnum]


    attr_reader :world, :frame, :fps

    # @!visibility private
    attr_reader :joystick_data, :joybutton_data, :joypad_data

    # @!group Simulation Control Functions

    # Play simulation.
    # @return [Boolean] success
    def play
      return false unless @paused
      @paused = false
      call_event(:onPlay)
      true
    end

    # Pause simulation.
    # @return [Boolean] success
    def pause
      return false if @paused
      @paused = true
      call_event(:onPause)
      true
    end

    # Play/pause simulation.
    # @return [Boolean] success
    def toggle_play
      @paused ? play : pause
    end

    # Determine if simulation is playing.
    # @return [Boolean]
    def is_playing?
      !@paused
    end

    # Determine if simulation is paused.
    # @return [Boolean]
    def is_paused?
      @paused
    end

    # Get simulation update rate, the number of times to update newton world
    # per frame.
    # @return [Fixnum] A value between 1 and 100.
    def get_update_rate
      @update_rate
    end

    # Set simulation update rate, the number of times to update newton world
    # per frame.
    # @param [Fixnum] rate A value between 1 and 100.
    # @return [Fixnum] The new update rate.
    def set_update_rate(rate)
      @update_rate = AMS.clamp(rate.to_i, 1, 100)
    end

    # Get simulation update time step in seconds.
    # @return [Numeric]
    def get_update_timestep
      @update_timestep
    end

    # Set simulation update time step in seconds.
    # @param [Numeric] time_step This value is clamped between +1/1200.0+ and
    #   +1/30.0+. Normal update time step is +1/60.0+.
    # @return [Numeric] The new update time step.
    def set_update_timestep(time_step)
      @update_timestep = AMS.clamp(time_step, 1/1200.0, 1/30.0)
    end

    # Get simulation mode.
    # * 0 - Interactive mode: The pick and drag tool and orbiting camera via the
    #   middle mouse button is enabled.
    # * 1 - Game mode: The pick and drag tool and orbiting camera via the middle
    #   mouse button is disabled.
    # @return [Fixnum]
    def get_mode
      @mode
    end

    # Set simulation mode.
    # * 0 - Interactive mode: The pick and drag tool and orbiting camera via the
    #   middle mouse button is enabled.
    # * 1 - Game mode: The pick and drag tool and orbiting camera via the middle
    #   mouse button is disabled.
    # @param [Fixnum] mode
    # @return [Fixnum] The new mode.
    def set_mode(mode)
      @mode = mode == 1 ? 1 : 0
    end

    # @!endgroup
    # @!group Cursor Functions

    # Get active cursor.
    # @return [Fixnum] Cursor id.
    def get_cursor
      @cursor_id
    end

    # Set active cursor.
    # @example
    #   onStart {
    #     # Set game mode.
    #     simulation.set_mode 1
    #     # Set target cursor.
    #     simulation.set_cursor MSPhysics::CURSORS[:target]
    #   }
    # @param [Fixnum] id Cursor id.
    # @return [Fixnum] The new cursor id.
    # @see MSPhysics::CURSORS
    def set_cursor(id)
      @cursor_id = id.to_i
      onSetCursor
      @cursor_id
    end

    # Get cursor position in view coordinates.
    # @return [Array<Fixnum>] +[x,y]+
    def get_cursor_pos
      @cursor_pos.dup
    end

    # Set cursor position in view coordinates.
    # @param [Fixnum] x
    # @param [Fixnum] y
    # @return [Array<Fixnum>] An array of two integer values containing the new
    #   cursor position - +[x,y]+.
    def set_cursor_pos(x,y)
      AMS::Cursor.set_pos(x.to_i, y.to_i, 2)
      @cursor_pos = AMS::Cursor.get_pos(2)
      @cursor_pos.dup
    end

    # Show/hide mouse cursor.
    # @param [Boolean] state
    # @return [Boolean] Whether visibility state changed.
    def show_cursor(state)
      AMS::Cursor.show(state)
    end

    # Determine whether cursor is visible.
    # @return [Boolean]
    def cursor_visible?
      AMS::Cursor.is_visible?
    end

    # @!endgroup
    # @!group Mode and Debug Draw Functions

    # Set view full screen.
    # @param [Boolean] state
    # @return [void]
    # @example
    #   onStart {
    #     simulation.view_full_screen(true)
    #   }
    #   onEnd {
    #     simulation.view_full_screen(false)
    #   }
    def view_full_screen(state)
      AMS::Sketchup.show_toolbar_container(5, !state, false)
      AMS::Sketchup.show_scenes_bar(!state, false)
      AMS::Sketchup.show_status_bar(!state, false)
      AMS::Sketchup.set_viewport_border(!state)
      r1 = AMS::Sketchup.set_menu_bar(!state)
      r2 = AMS::Sketchup.switch_full_screen(state)
      AMS::Sketchup.refresh unless r1 || r2
      AMS::Sketchup.show_dialogs(!state)
      AMS::Sketchup.show_toolbars(!state)
    end

    # Enable/disable the drawing of collision contact points.
    # @param [Boolean] state
    # @return [Boolean] The new state.
    def show_contact_points(state)
      @contact_points[:show] = state ? true : false
    end

    # Determine if the drawing of collision contact points is enabled.
    # @return [Boolean]
    def contact_points_visible?
      @contact_points[:show]
    end

    # Enable/disable the drawing of collision contact forces.
    # @param [Boolean] state
    # @return [Boolean] The new state.
    def show_contact_forces(state)
      @contact_forces[:show] = state ? true : false
    end

    # Determine if the drawing of collision contact forces is enabled.
    # @return [Boolean]
    def contact_forces_visible?
      @contact_forces[:show]
    end

    # Enable/disable the drawing of body world axes aligned bounding box.
    # @param [Boolean] state
    # @return [Boolean] The new state.
    def show_aabb(state)
      @aabb[:show] = state ? true : false
    end

    # Determine if the drawing of body world axes aligned bounding box is
    # enabled.
    # @return [Boolean]
    def aabb_visible?
      @aabb[:show]
    end

    # Enable/disable the drawing of body collision wireframe.
    # @param [Boolean] state
    # @return [Boolean] The new state.
    def show_collision_wireframe(state)
      state = state ? true : false
      return state if state == @collision_wireframe[:show]
      ro = Sketchup.active_model.rendering_options
      if state
        @collision_wireframe[:show_edges] = ro['EdgeDisplayMode']
        @collision_wireframe[:show_profiles] = ro['DrawSilhouettes']
        ro['EdgeDisplayMode'] = false
        ro['DrawSilhouettes'] = false
      else
        ro['EdgeDisplayMode'] = @collision_wireframe[:show_edges]
        ro['DrawSilhouettes'] = @collision_wireframe[:show_profiles]
      end
      @collision_wireframe[:show] = state
    end

    # Determine if the drawing of body collision wireframe is enabled.
    # @return [Boolean]
    def collision_wireframe_visible?
      @collision_wireframe[:show]
    end

    # Enable/disable the drawing of body centre of mass axes.
    # @param [Boolean] state
    # @return [Boolean] The new state.
    def show_axes(state)
      @axes[:show] = state ? true : false
    end

    # Determine if the drawing of body centre of mass axes is enabled.
    # @return [Boolean]
    def axes_visible?
      @axes[:show]
    end

    # Get continuous collision state for all bodies. Continuous collision
    # prevents bodies from passing each other at high speeds.
    # @return [Boolean]
    def get_continuous_collision_state
      @ccm
    end

    # Set continuous collision state for all bodies. Continuous collision
    # prevents bodies from passing each other at high speeds.
    # @param [Boolean] state
    # @return [Boolean] The new state.
    def set_continuous_collision_state(state)
      @ccm = state ? true : false
      world_address = @world.get_address
      ovs = MSPhysics::Newton.is_object_validation_enabled?
      MSPhysics::Newton.enable_object_validation(false)
      if @ccm
        body_address = MSPhysics::Newton::World.get_first_body(world_address)
        while body_address
          unless MSPhysics::Newton::Body.get_continuous_collision_state(body_address)
            MSPhysics::Newton::Body.set_continuous_collision_state(body_address, true)
            @cc_bodies << body_address unless @cc_bodies.include?(body_address)
          end
          body_address = MSPhysics::Newton::World.get_next_body(world_address, body_address)
        end
      else
        @cc_bodies.each { |body_address|
          next unless MSPhysics::Newton::Body.is_valid?(body_address)
          MSPhysics::Newton::Body.set_continuous_collision_state(body_address, false)
        }
        @cc_bodies.clear
      end
      MSPhysics::Newton.enable_object_validation(ovs)
      @ccm
    end

    # Show/hide all entities associated with the bodies.
    # @param [Boolean] state
    # @return [Boolean] The new state.
    def show_bodies(state)
      @show_bodies = state ? true : false
      if @show_bodies
        @hidden_entities.each { |e|
          e.visible = true if e.valid?
        }
        @hidden_entities.clear
      else
        world_address = @world.get_address
        ovs = MSPhysics::Newton.is_object_validation_enabled?
        MSPhysics::Newton.enable_object_validation(false)
        body_address = MSPhysics::Newton::World.get_first_body(world_address)
        while body_address
          data = MSPhysics::Newton::Body.get_user_data(body_address)
          if data.is_a?(MSPhysics::Body) && data.get_group.visible?
            data.get_group.visible = false
            @hidden_entities << data.get_group
          end
          body_address = MSPhysics::Newton::World.get_next_body(world_address, body_address)
        end
        MSPhysics::Newton.enable_object_validation(ovs)
      end
      @show_bodies
    end

    # Determine if all entities associated with the bodies are visible.
    # @return [Boolean]
    def bodies_visible?
      @show_bodies
    end

    # @!endgroup
    # @!group Body/Group Functions

    # Get body by group/component.
    # @param [Sketchup::Group, Sketchup::ComponentInstance] group
    # @return [Body, nil]
    def get_body_by_group(group)
=begin
      AMS.validate_type(group, Sketchup::Group, Sketchup::ComponentInstance)
      world_address = @world.get_address
      ovs = MSPhysics::Newton.is_object_validation_enabled?
      MSPhysics::Newton.enable_object_validation(false)
      body_address = MSPhysics::Newton::World.get_first_body(world_address)
      while body_address
        data = MSPhysics::Newton::Body.get_user_data(body_address)
        if data.is_a?(MSPhysics::Body) && data.get_group == group
          MSPhysics::Newton.enable_object_validation(ovs)
          return data
        end
        body_address = MSPhysics::Newton::World.get_next_body(world_address, body_address)
      end
      MSPhysics::Newton.enable_object_validation(ovs)
      nil
=end
      AMS.validate_type(group, Sketchup::Group, Sketchup::ComponentInstance)
      data = MSPhysics::Newton::Body.get_body_data_by_group(group)
      data.is_a?(MSPhysics::Body) && data.get_world == @world ? data : nil
    end

    # Reference body by group name.
    # @param [String] name Group name.
    # @return [Body, nil] A body object or nil if not found.
    def get_body_by_name(name)
      world_address = @world.get_address
      ovs = MSPhysics::Newton.is_object_validation_enabled?
      MSPhysics::Newton.enable_object_validation(false)
      body_address = MSPhysics::Newton::World.get_first_body(world_address)
      while body_address
        data = MSPhysics::Newton::Body.get_user_data(body_address)
        if (data.is_a?(MSPhysics::Body) && data.get_group.name == name)
          MSPhysics::Newton.enable_object_validation(ovs)
          return data
        end
        body_address = MSPhysics::Newton::World.get_next_body(world_address, body_address)
      end
      MSPhysics::Newton.enable_object_validation(ovs)
      nil
    end

    # Reference a list of bodies by group name.
    # @param [String] name Group name.
    # @return [Body, nil] A body object or nil if not found.
    def get_bodies_by_name(name)
      world_address = @world.get_address
      ovs = MSPhysics::Newton.is_object_validation_enabled?
      MSPhysics::Newton.enable_object_validation(false)
      body_address = MSPhysics::Newton::World.get_first_body(world_address)
      bodies = []
      while body_address
        data = MSPhysics::Newton::Body.get_user_data(body_address)
        if (data.is_a?(MSPhysics::Body) && data.get_group.name == name)
          MSPhysics::Newton.enable_object_validation(ovs)
          bodies << data
        end
        body_address = MSPhysics::Newton::World.get_next_body(world_address, body_address)
      end
      MSPhysics::Newton.enable_object_validation(ovs)
      bodies
    end

    # Reference a top level group by name.
    # @param [String] name Group name.
    # @return [Sketchup::Group, Sketchup::ComponentInstance, nil] A group or nil
    #   if not found.
    def get_group_by_name(name)
      Sketchup.active_model.entities.each { |e|
        return e if (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.name == name
      }
      nil
    end

    # Reference a list of top level groups by name.
    # @param [String] name Group name.
    # @return [Array<Sketchup::Group, Sketchup::ComponentInstance>] An array of
    #   groups/components.
    def get_groups_by_name(name)
      groups = []
      Sketchup.active_model.entities.each { |e|
        groups << e if (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.name == name
      }
      groups
    end

    # Get all joints associated with a particular group.
    # @param [Sketchup::Group, Sketchup::ComponentInstance] group
    # @return [Array<Joint>]
    def get_joints_by_group(group)
      AMS.validate_type(group, Sketchup::Group, Sketchup::ComponentInstance)
      joints = []
      MSPhysics::Newton::Joint.get_joint_datas_by_group(group).each { |data|
        if data.is_a?(MSPhysics::Joint) && data.world == @world
          joints << data
        end
      }
      joints
    end

    # Get the first joint associated with a particular group.
    # @param [Sketchup::Group, Sketchup::ComponentInstance] group
    # @return [Joint, nil]  A joint or nil if not found.
    def get_joint_by_group(group)
      AMS.validate_type(group, Sketchup::Group, Sketchup::ComponentInstance)
      data = MSPhysics::Newton::Joint.get_joint_data_by_group(group)
      data.is_a?(MSPhysics::Joint) && data.world == @world ? data : nil
    end

    # Get all joints with a particular name.
    # @param [String] name Joint Name.
    # @return [Array<Joint>]
    def get_joints_by_name(name)
      joints = []
      @world.get_joints.each { |joint|
        joints << joint if joint.name == name
      }
      joints
    end

    # Get the first joint with a particular name.
    # @param [String] name Joint Name.
    # @return [Joint, nil] A joint or nil if not found.
    def get_joint_by_name(name)
      @world.get_joints.each { |joint|
        return joint if joint.name == name
      }
      nil
    end

    # Add a group/component to simulation.
    # @raise [TypeError] if the specified entity is already part of simulation.
    # @raise [TypeError] if the entity doesn't meet demands for being a valid
    #   physics body.
    # @raise [MSPhysics::ScriptException] if there is an error in body script.
    # @param [Sketchup::Group, Sketchup::ComponentInstance] group
    # @return [Body]
    def add_group(group)
      AMS.validate_type(group, Sketchup::Group, Sketchup::ComponentInstance)

      if get_body_by_group(group)
        raise(TypeError, "Entity #{group} is already part of simulation!", caller)
      end

      default = MSPhysics::DEFAULT_BODY_SETTINGS
      bdict = 'MSPhysics Body'

      shape = group.get_attribute(bdict, 'Shape', default[:shape])
      body = MSPhysics::Body.new(@world, group, shape)

      if group.get_attribute(bdict, 'Weight Control') == 'Mass'
        body.set_mass group.get_attribute(bdict, 'Mass', default[:mass])
      else
        body.set_density group.get_attribute(bdict, 'Density', default[:density])
      end
      body.set_static_friction group.get_attribute(bdict, 'Static Friction', default[:static_friction])
      body.set_dynamic_friction group.get_attribute(bdict, 'Dynamic Friction', default[:dynamic_friction])
      body.set_elasticity group.get_attribute(bdict, 'Elasticity', default[:elasticity])
      body.set_softness group.get_attribute(bdict, 'Softness', default[:softness])
      body.set_friction_state group.get_attribute(bdict, 'Enable Friction', default[:enable_friction])
      body.set_magnet_force group.get_attribute(bdict, 'Magnet Force', default[:magnet_force])
      body.set_magnet_range group.get_attribute(bdict, 'Magnet Range', default[:magnet_range])
      body.set_static group.get_attribute(bdict, 'Static', default[:static])
      body.set_frozen group.get_attribute(bdict, 'Frozen', default[:frozen])
      body.set_magnetic group.get_attribute(bdict, 'Magnetic', default[:magnetic])
      body.set_collidable group.get_attribute(bdict, 'Collidable', default[:collidable])
      body.set_auto_sleep_state group.get_attribute(bdict, 'Auto Sleep', default[:auto_sleep])
      body.set_continuous_collision_state group.get_attribute(bdict, 'Continuous Collision', default[:continuous_collision])
      body.set_linear_damping group.get_attribute(bdict, 'Linear Damping', default[:linear_damping])
      ad = group.get_attribute(bdict, 'Angular Damping', default[:angular_damping])
      body.set_angular_damping([ad,ad,ad])
      body.enable_gravity group.get_attribute(bdict, 'Enable Gravity', default[:enable_gravity])

      if group.get_attribute(bdict, 'Enable Script', default[:enable_script])
        script = group.get_attribute('MSPhysics Script', 'Value')
        begin
          #Kernel.eval(script, body.get_binding, MSPhysics::SCRIPT_NAME, 1)
          body.instance_eval(script, MSPhysics::SCRIPT_NAME, 1)
        rescue Exception => e
          ref = nil
          test = MSPhysics::SCRIPT_NAME + ':'
          err_message = e.message
          err_backtrace = e.backtrace
          if RUBY_VERSION !~ /1.8/
            err_message.force_encoding("UTF-8")
            err_backtrace.each { |i| i.force_encoding("UTF-8") }
          end
          err_backtrace.each { |location|
            if location.include?(test)
              ref = location
              break
            end
          }
          ref = err_message if !ref && err_message.include?(test)
          line = ref ? ref.split(test, 2)[1].split(':', 2)[0].to_i : nil
          msg = "#{e.class.to_s[0] =~ /a|e|i|o|u/i ? 'An' : 'A'} #{e.class} has occurred while evaluating entity script#{line ? ', line ' + line.to_s : nil}:\n#{err_message}"
          raise MSPhysics::ScriptException.new(msg, err_backtrace, group, line)
        end if script.is_a?(String)
      end

      if group.get_attribute(bdict, 'Enable Thruster', default[:enable_thruster])
        controller = group.get_attribute(bdict, 'Thruster Controller')
        if controller.is_a?(String) && !controller.empty?
          lock_axis = group.get_attribute(bdict, 'Thruster Lock Axis', default[:thruster_lock_axis])
          @thrusters[body] = { :controller => controller, :lock_axis => lock_axis }
        end
      end

      if group.get_attribute(bdict, 'Enable Emitter', default[:enable_emitter])
        controller = group.get_attribute(bdict, 'Emitter Controller')
        if controller.is_a?(String) && !controller.empty?
          lock_axis = group.get_attribute(bdict, 'Emitter Lock Axis', default[:emitter_lock_axis])
          rate = AMS.clamp(group.get_attribute(bdict, 'Emitter Rate', default[:emitter_rate]).to_i, 1, nil)
          lifetime = AMS.clamp(group.get_attribute(bdict, 'Emitter Lifetime', default[:emitter_lifetime]).to_i, 0, nil)
          @emitters[body] = { :controller => controller, :lock_axis => lock_axis, :rate => rate, :lifetime => lifetime }
        end
      end

      @saved_transformations[group] = group.transformation
      body
    end

    # Remove a group/component from simulation.
    # @param [Sketchup::Group, Sketchup::ComponentInstance] group
    # @return [Boolean] success
    def remove_group(group)
      AMS.validate_type(group, Sketchup::Group, Sketchup::ComponentInstance)
      body = get_body_by_group(group)
      return false unless body
      body.destroy
      true
    end

    # @overload emit_body(body, force, life_time)
    #   Create a copy of the body and apply force to it.
    #   @param [Body] body The body to emit.
    #   @param [Geom::Vector3d, Array<Numeric>] force in Newtons.
    #   @param [Fixnum] life_time Body life time in frames. A life of 0 will
    #     give the body an endless life.
    #   @return [Body] A new body object.
    # @overload emit_body(body, transformation, force, life_time)
    #   Create a copy of the body at the specified transformation and apply
    #   force to it.
    #   @param [Body] body A body to emit.
    #   @param [Geom::Vector3d, Array<Numeric>] force A force to apply in
    #     Newtons.
    #   @param [Geom::Transformation, Array<Numeric>] transformation
    #   @param [Fixnum] life_time Body life time in frames. A life of 0 will
    #     give a new body an endless lifetime.
    #   @return [Body] A new body object.
    # @example
    #   onUpdate {
    #     # Emit body every 5 frames if key 'space' is down.
    #     if key('space') == 1 && frame % 5 == 0
    #       dir = this.get_group.transformation.yaxis
    #       dir.length = 1000
    #       simulation.emit_body(this, dir, 100)
    #     end
    #   }
    def emit_body(*args)
      if args.size == 3
        body, force, life_time = args
      elsif args.size == 4
        body, tra, force, life_time = args
      else
        raise(ArgumentError, "Expected 3 or 4 parameters, but got #{args.size}.", caller)
      end
      life_time = life_time.to_i.abs
      new_body = args.size == 3 ? body.copy(true) : body.copy(tra, true)
      new_body.set_static(false)
      new_body.set_collidable(true)
      new_body.set_continuous_collision_state(true)
      new_body.add_force(force)
      @emitted_bodies[new_body] = life_time == 0 ? 0 : @frame + life_time
      @created_entities << new_body.get_group
      new_body
    end

    # Destroy all emitted bodies and the entities associated with them.
    # @return [Fixnum] The number of emitted bodies destroyed.
    def destroy_all_emitted_bodies
      count = 0
      @emitted_bodies.each { |body, life|
        if body.is_valid?
          body.destroy
          count += 1
        end
      }
      @emitted_bodies.clear
      @created_entities.each { |e|
        e.erase! if e.valid?
      }
      @created_entities.clear
      count
    end

    # Erase group/component when simulation resets. This method is commonly used
    # for copied bodies. <tt>Body.#copy</tt> method doesn't register created
    # entity to the "erase" queue. When simulation resets created entities
    # remain un-deleted. To erase these entities, one could simply use this
    # method.
    # @param [Sketchup::Drawingelement] entity
    # @return [void]
    # @example Erasing copied entities.
    #   onUpdate {
    #     if frame % 10 == 0 && key('space') == 1
    #       pt = Geom::Point3d.new( rand(1000), rand(1000), rand(1000) )
    #       tra = Geom::Transformation.new(pt)
    #       body = this.copy(tra, true)
    #       simulation.erase_on_end(entity)
    #     end
    #   }
    def erase_on_end(entity)
      AMS.validate_type(entity, Sketchup::Drawingelement)
      @created_entities << entity
    end

    # @!endgroup
    # @!group Text Control Functions

    # Display text on screen in logged form.
    # @param [String] text
    # @param [Sketchup::Color] color Text color.
    # @return [String] Displayed text
    def log_line(text, color = MSPhysics::WATERMARK_COLOR)
      model = Sketchup.active_model
      if @lltext[:mat].nil? || @lltext[:mat].deleted?
        @lltext[:mat] = model.materials.add('MSPLogLine')
      end
      if @lltext[:ent].nil? || @lltext[:ent].deleted?
        @lltext[:ent] = MSPhysics.add_watermark_text2(10, 50, '', 'LogLine')
        @lltext[:ent].material = @lltext[:mat]
      end
      color = Sketchup::Color.new(color) unless color.is_a?(Sketchup::Color)
      @lltext[:mat].color = color if @lltext[:mat].color.to_i != color.to_i
      @lltext[:log] << text.to_s
      @lltext[:log].shift if @lltext[:log].size > @lltext[:limit]
      @lltext[:ent].text = @lltext[:log].join("\n")
    end

    # Get log-line text limit.
    # @return [Fixnum]
    def get_log_line_limit
      @lltext[:limit]
    end

    # Set log-line text limit.
    # @param [Fixnum] limit Desired limit, a value between 1 and 1000.
    # @return [Fixnum] The new limit.
    def set_log_line_limit(limit)
      @lltext[:limit] = AMS.clamp(limit, 1, 1000)
      ls = @lltext[:log].size
      if ls > @lltext[:limit]
        @lltext[:log] = @lltext[:log][ls-@lltext[:limit]...ls]
        if @lltext[:ent] != nil && @lltext[:ent].valid?
          @lltext[:ent].text = @lltext[:log].join("\n")
        end
      end
    end

    # Clear log-line text.
    # @return [void]
    def clear_log_line
      if @lltext[:ent] != nil && @lltext[:ent].valid?
        @lltext[:ent].text = ''
      end
      @lltext[:log].clear
    end

    # Display text on screen.
    # @param [String] text A text to display.
    # @param [Sketchup::Color] color Text color.
    # @return [String] Displayed text
    def display_note(text, color = MSPhysics::WATERMARK_COLOR)
      model = Sketchup.active_model
      if @dntext[:mat].nil? || @dntext[:mat].deleted?
        @dntext[:mat] = model.materials.add('MSPDisplayNote')
      end
      if @dntext[:ent].nil? || @dntext[:ent].deleted?
        @dntext[:ent] = MSPhysics.add_watermark_text2(10, 10, '', 'DisplayNote')
        @dntext[:ent].material = @dntext[:mat]
      end
      color = Sketchup::Color.new(color) unless color.is_a?(Sketchup::Color)
      @dntext[:mat].color = color if @dntext[:mat].color.to_i != color.to_i
      @dntext[:ent].text = text.to_s
    end

    # Clear display-note text.
    # @return [void]
    def clear_display_note
      if @dntext[:ent] != nil && @dntext[:ent].valid?
        @dntext[:ent].text = ''
      end
    end

    # @!endgroup
    # @!group Viewport Drawing Functions

    # Draw 2D geometry into view.
    # @param [String, Symbol] type Drawing type. Use one of the following:
    #   * <tt>"points"</tt> - Draw a collection of points. Each vertex is
    #     treated as a single point. Vertex n defines point n. N points are
    #     drawn.
    #   * <tt>"lines"</tt> - Draw a collection of independent lines. Each pair
    #     of vertices is treated as a single line. Vertices 2n-1 and 2n define
    #     line n. N/2 lines are drawn.
    #   * <tt>"line_strip"</tt> - Draw a connected group of line segments from
    #     the first vertex to the last. Vertices n and n+1 define line n. N-1
    #     lines are drawn.
    #   * <tt>"line_loop"</tt> - Draw a connected group of line segments from
    #     the first vertex to the last, then back to the first. Vertices n and
    #     n+1 define line n. The last line, however, is defined by vertices N
    #     and 1. N lines are drawn.
    #   * <tt>"triangles"</tt> - Draw a group of independent triangles. Each
    #     triplet of vertices is considered a single triangle. Vertices 3n-2,
    #     3n-1, and 3n define triangle n. N/3 triangles are drawn.
    #   * <tt>"triangle_strip"</tt> - Draw a connected group of triangles. One
    #     triangle is defined for each vertex presented after the first two
    #     vertices. For odd n, vertices n, n+1, and n+2 define triangle n. For
    #     even n, vertices n+1, n, and n+2 define triangle n. N-2 triangles are
    #     drawn.
    #   * <tt>"triangle_fan"</tt> - Draw a connected group of triangles. One
    #     triangle is defined for each vertex presented after the first two
    #     vertices. Vertices 1, n+1, and n+2 define triangle n. N-2 triangles
    #     are drawn.
    #   * <tt>"quads"</tt> - Draw a collection of independent quadrilaterals. A
    #     group of four vertices is treated as a single quadrilateral. Vertices
    #     4n-3, 4n-2, 4n-1, and 4n define quadrilateral n. N/4 quadrilaterals
    #     are drawn.
    #   * <tt>"quad_strip"</tt> - Draw a collection of connected quadrilaterals.
    #     One quadrilateral is defined for each pair of vertices presented after
    #     the first pair. Vertices 2n-1, 2n, 2n+2, and 2n+1 define quadrilateral n.
    #     N/2-1 quadrilaterals are drawn. Note that the order in which
    #     vertices are used to construct a quadrilateral from strip data is
    #     different from that used with independent data.
    #   * <tt>"polygon"</tt> - Draws a single convex polygon. Vertices 1 through
    #     N define this polygon.
    # @param [Array<Geom::Point3d, Array<Numeric>>] points An array of points.
    # @param [Sketchup::Color, Array, String] color Drawing color.
    # @param [Fixnum] width Line width in pixels.
    # @param [String] stipple Line stipple. Use one of the following:
    #  * <tt>"."</tt> - dotted line
    #  * <tt>"-"</tt> - short-dashed line
    #  * <tt>"_"</tt> - long-dashed line
    #  * <tt>"-.-"</tt> - dash dot dash line
    #  * <tt>""</tt> - solid line
    # @return [void]
    def draw2d(type, points, color = 'black', width = 1, stipple = '')
      type = case type.to_s.downcase.gsub(/\s/i, '_').to_sym
        when :points
          GL_POINTS
        when :lines
          GL_LINES
        when :line_strip
          GL_LINE_STRIP
        when :line_loop
          GL_LINE_LOOP
        when :triangles
          GL_TRIANGLES
        when :triangle_strip
          GL_TRIANGLE_STRIP
        when :triangle_fan
          GL_TRIANGLE_FAN
        when :quads
          GL_QUADS
        when :quad_strip
          GL_QUAD_STRIP
        when :polygon
          GL_POLYGON
      else
        raise(TypeError, 'Invalid type!', caller)
      end
      @draw_queue << [type, points, color, width, stipple, 0]
    end

    # Draw 3D geometry into view.
    # @param (see #draw2d)
    # @return (see #draw2d)
    def draw3d(type, points, color = 'black', width = 1, stipple = '')
      type = case type.to_s.downcase.gsub(/\s/i, '_').to_sym
        when :points
          GL_POINTS
        when :lines
          GL_LINES
        when :line_strip
          GL_LINE_STRIP
        when :line_loop
          GL_LINE_LOOP
        when :triangles
          GL_TRIANGLES
        when :triangle_strip
          GL_TRIANGLE_STRIP
        when :triangle_fan
          GL_TRIANGLE_FAN
        when :quads
          GL_QUADS
        when :quad_strip
          GL_QUAD_STRIP
        when :polygon
          GL_POLYGON
      else
        raise(TypeError, 'Invalid type!', caller)
      end
      @draw_queue << [type, points, color, width, stipple, 1]
    end

    # Draw 3D points with custom style.
    # @param [Array<Geom::Point3d, Array<Numeric>>] points An array of points.
    # @param [Fixnum] size Point size in pixels.
    # @param [Fixnum] style Point style. Use one of the following:
    #   0. none
    #   1. open square
    #   2. filled square
    #   3. + cross
    #   4. x cross
    #   5. star
    #   6. open triangle
    #   7. filled triangle
    # @param [Sketchup::Color, Array, String] color Point color.
    # @param [Fixnum] width Line width in pixels.
    # @param [String] stipple Line stipple. Use one of the following:
    #  * <tt>"."</tt> - dotted line
    #  * <tt>"-"</tt> - short-dashed line
    #  * <tt>"_"</tt> - long-dashed line
    #  * <tt>"-.-"</tt> - dash dot dash line
    #  * <tt>""</tt> - solid line
    # @return [void]
    def draw_points(points, size = 1, style = 0, color = 'black', width = 1, stipple = '')
      @points_queue << [points, size, style, color, width, stipple]
    end

    # @!endgroup

    # @!group Music, Sound, and MIDI Functions

    # Play embedded sound by name. This can load WAVE, AIFF, RIFF, OGG, and VOC
    # formats.
    # @note If this function succeeds, it returns a channel the sound was
    #   registered to play on. The returned channel can be adjusted to desired
    #   volume and panning.
    # @example Play 3D effect when space is pressed.
    #   onKeyDown { |key, value, char|
    #     if key == 'space'
    #       channel = simulation.play_sound("MyEffect1", -1, 0)
    #       max_hearing_range = 1000 # Set hearing range to 1000 meters.
    #       simulation.set_sound_position(channel, this.get_position(1), max_hearing_range)
    #     end
    #   }
    # @param [String] name The name of embedded sound.
    # @param [Fixnum] channel The channel to play the sound at. Pass -1 to play
    #   sound at the available channel.
    # @param [Fixnum] repeat The number of times to play the sound plus one.
    #   Pass -1 to play sound infinite times.
    # @return [Fixnum, nil] A channel the sound is set to be played on or nil if
    #   mixer failed to play sound.
    # @raise [TypeError] if sound is invalid.
    def play_sound(name, channel = -1, repeat = 0)
      return unless MSPhysics.sdl_used?
      sound = MSPhysics::Sound.get_by_name(name)
      unless sound
        type = Sketchup.active_model.get_attribute('MSPhysics Sound Types', name, nil)
        unless type
          raise(TypeError, "Sound with name \"#{name}\" doesn't exist!", caller)
        end
        unless MSPhysics::EMBEDDED_SOUND_FORMATS.include?(type)
          raise(TypeError, "Sound format is not supported!", caller)
        end
        data = Sketchup.active_model.get_attribute('MSPhysics Sounds', name, nil)
        unless data
          raise(TypeError, "Sound with name \"#{name}\" doesn't exist!", caller)
        end
        buf = data.pack('l*')
        sound = MSPhysics::Sound.create_from_buffer(buf, buf.size)
        MSPhysics::Sound.set_name(sound, name)
      end
      MSPhysics::Sound.play(sound, channel, repeat)
    end

    # Play sound from path. This can load WAVE, AIFF, RIFF, OGG, VOC, and FLAC
    # formats.
    # @note If this function succeeds, it returns a channel the sound was
    #   registered to play on. The returned channel can be adjusted to desired
    #   volume and panning.
    # @param [String] path Full path of the sound.
    # @param [Fixnum] channel The channel to play the sound at. Pass -1 to play
    #   sound at the available channel.
    # @param [Fixnum] repeat The number of times to play the sound plus one.
    #   Pass -1 to play sound infinite times.
    # @return [Fixnum, nil] A channel the sound is set to be played on or nil if
    #   mixer failed to play sound.
    # @raise [TypeError] if sound is invalid.
    def play_sound2(path, channel = -1, repeat = 0)
      return unless MSPhysics.sdl_used?
      sound = MSPhysics::Sound.create_from_dir(path)
      MSPhysics::Sound.play(sound, channel, repeat)
    end

    # Stop the currently playing sound at channel.
    # @param [Fixnum] channel The channel returned by {#play_sound} or
    #   {#play_sound2} functions. Pass -1 to stop all sounds.
    # @return [Boolean] success
    def stop_sound(channel)
      return false unless MSPhysics.sdl_used?
      MSPhysics::Sound.stop(channel)
      true
    end

    # Set sound 3D position.
    # @note Sound volume and panning is adjusted automatically with respect to
    #   camera orientation. You don't need to call this function every frame if
    #   sound remains in constant position. You do, however, need to call this
    #   function if sound position changes.
    # @param [Fixnum] channel The channel the sound is being played on.
    # @param [Geom::Point3d, Array<Numeric>] pos Sound position in global space.
    # @param [Numeric] max_hearing_range The maximum hearing range of the sound
    #   in meters.
    # @return [Boolean] success
    def set_sound_position(channel, pos, max_hearing_range = 100)
      return false unless MSPhysics.sdl_used?
      MSPhysics::Sound.set_position_3d(channel, pos, max_hearing_range)
    end

    # Play embedded music by name. This can load WAVE, AIFF, RIFF, OGG, FLAC,
    # MOD, IT, XM, and S3M formats.
    # @example Start playing music when simulation starts.
    #   onStart {
    #     simulation.play_music("MyBackgroundMusic", -1)
    #   }
    # @param [String] name The name of embedded music.
    # @param [Fixnum] repeat The number of times to play the music plus one.
    #   Pass -1 to play music infinite times.
    # @return [Boolean] success
    # @raise [TypeError] if music is invalid.
    def play_music(name, repeat = 0)
      return false unless MSPhysics.sdl_used?
      music = MSPhysics::Music.get_by_name(name)
      unless music
        type = Sketchup.active_model.get_attribute('MSPhysics Sound Types', name, nil)
        unless type
          raise(TypeError, "Music with name \"#{name}\" doesn't exist!", caller)
        end
        unless MSPhysics::EMBEDDED_MUSIC_FORMATS.include?(type)
          raise(TypeError, "Music format is not supported!", caller)
        end
        data = Sketchup.active_model.get_attribute('MSPhysics Sounds', name, nil)
        unless data
          raise(TypeError, "Music with name \"#{name}\" doesn't exist!", caller)
        end
        buf = data.pack('l*')
        music = MSPhysics::Music.create_from_buffer(buf, buf.size)
        MSPhysics::Music.set_name(music, name)
      end
      MSPhysics::Music.play(music, repeat)
    end

    # Play music from path. This can load WAVE, AIFF, RIFF, OGG, FLAC, MOD, IT,
    # XM, and S3M formats.
    # @param [String] path Full path of the music.
    # @param [Fixnum] repeat The number of times to play the music plus one.
    #   Pass -1 to play music infinite times.
    # @return [Boolean] success
    # @raise [TypeError] if music is invalid.
    def play_music2(path, repeat = 0)
      return false if MSPhysics.sdl_used?
      music = MSPhysics::Music.create_from_dir(path)
      MSPhysics::Music.play(music, repeat)
    end

    # Stop the currently playing music.
    # @return [Boolean] success
    def stop_music
      return false unless MSPhysics.sdl_used?
      MSPhysics::Music.stop
      true
    end

    # Play MIDI note.
    # @note Setting channel to 9 will play midi notes from the "General MIDI
    #   Percussion Key Map." Any other channel will play midi notes from the
    #   "General MIDI Instrument Patch Map". If channel is set to 9, the
    #   instrument parameter will have no effect and the note parameter will be
    #   used to play particular percussion sound, if note's value is between 27
    #   and 87. According to my experiments, values outside that 27-87 range
    #   won't yield any sounds.
    # @note Some instruments have notes that never seem to end. For this reason
    #   it might come in handy to use {#stop_midi_note} function when needed.
    # @param [Fixnum] instrument A value between 0 and 127. See link below for
    #   supported instruments and their identifiers.
    # @param [Fixnum] note A value between 0 and 127. Each instrument has a
    #   maximum of 128 notes.
    # @param [Fixnum] channel A value between 0 and 15. Each note has a maximum
    #   of 16 channels. To play multiple sounds of same type at the same time,
    #   change channel value to an unused one. Remember that channel 9 is
    #   subjected to different instrument patch and it will change the behaviour
    #   of this function; see note above.
    # @param [Fixnum] volume A value between 0 and 127. 0 means quiet/far and
    #   127 means close/loud.
    # @return [Fixnum, nil] Midi note ID or nil if MIDI interface failed to play
    #   the note.
    # @see http://wiki.fourthwoods.com/midi_file_format#general_midi_instrument_patch_map General MIDI Instrument Patch Map
    def play_midi_note(instrument, note = 63, channel = 0, volume = 127)
      AMS::MIDI.play_note(instrument, note, channel, volume);
    end

    # Stop MIDI note.
    # @param [Fixnum] id A MIDI note identifier returned by the
    #   {#play_midi_note} function. Pass -1 to stop all midi notes.
    # @return [Boolean] success
    def stop_midi_note(id)
      if id == -1
        AMS::MIDI.reset
      else
        AMS::MIDI.stop_note(id)
      end
    end

    # Set MIDI note position in 3D space.
    # @note Sound volume and panning is not adjusted automatically with respect
    #   to camera orientation. It is required to manually call this function
    #   every frame until the note is stopped or has finished playing. Sometimes
    #   it's just enough to call this function once after playing the note.
    #   Other times, when the note is endless or pretty long, it might be useful
    #   to update position of the note every frame until the note ends or is
    #   stopped. Meantime, there is no function to determine when the note ends.
    #   It is up to the user to decide for how long to call this function or
    #   when to stop calling this function.
    # @note When it comes to setting 3D positions of multiple sounds, make sure
    #   to play each sound on separate channel. That is, play sound 1 on channel
    #   0, sound 2 on channel 1, sound 3 on channel 2, and etcetera until
    #   channel gets to 15, as there are only 15 channels available. Read the
    #   note below to find out why each sound is supposed to be played on
    #   separate channel. I think it would make more sense if the function was
    #   renamed to <tt>set_midi_channel_position</tt> and had the 'id' parameter
    #   replaced with 'channel'.
    # @note This function works by adjusting panning and volume of the note's
    #   and instrument's channel, based on camera's angle and distance to the
    #   origin of the sound. Now, there is only one function that adjusts stereo
    #   and panning, but it adjusts panning and volume of all notes and
    #   instruments that are played on same channel. As of my research, I
    #   haven't found a way to adjust panning and volume of channel that belongs
    #   to particular note and instrument. There's only a function that can
    #   adjust panning and volume of channel that belongs to all notes and
    #   instruments that are played on particular channel. For instance, if you
    #   play instrument 1 and instrument 2 both on channel zero, they will still
    #   play simultaneously, without cancelling out each other, as if they are
    #   playing on separate channels, but when it comes to adjusting panning and
    #   volume of one of them, the properties of both sounds will be adjusted.
    #   This means that this function is only limited to playing 16 3D sounds,
    #   with each sound played on different channel. Otherwise, sounds played on
    #   same channel at different locations, will endup being tuned as if they
    #   are playing from the same location.
    # @example Play 3D note.
    #   onKeyDown { |k,v,c|
    #     if k == 'space'
    #       id = simulation.play_midi_note(2, 63, 0, 127)
    #       simulation.set_midi_note_position(id, this.get_position(1), 100) if id
    #     end
    #   }
    # @param [Fixnum] id A MIDI note identifier returned by the
    #   {#play_midi_note} function.
    # @param [Geom::Point3d, Array<Numeric>] pos MIDI note position in global
    #   space.
    # @param [Numeric] max_hearing_range MIDI note maximum hearing range in
    #   meters.
    # @return [Boolean] success
    def set_midi_note_position(id, pos, max_hearing_range = 100)
      AMS::MIDI.set_note_position(id, pos, max_hearing_range)
    end

    # @!endgroup
    # @!group Particle Effects

    # Create a new particle.
    # @param [Hash] opts Particle options.
    # @option opts [Geom::Point3d, Array] :position (ORIGIN) Starting position.
    #   Position is altered by particle velocity and time.
    # @option opts [Geom::Vector3d, Array] :velocity (nil) Starting velocity
    #   in inches per second. Pass nil if velocity is not necessary.
    # @option opts [Numeric] :velocity_damp (0.0) Velocity damping,
    #   a value between 0.0 and 1.0.
    # @option opts [Geom::Vector3d, Array] :gravity (nil) Gravitational
    #   acceleration in inches per second per second. Pass nil if gravity is not
    #   necessary.
    # @option opts [Numeric] :radius (1.0) Starting radius in inches, a value
    #   between 0.01 and 10000. Radius alters depending on a scale parameter.
    # @option opts [Numeric] :scale (1.01) Radius scale ratio per second, a
    #   value between 0.001 and 1000. If radius becomes less than 0.01 or more
    #   than 10000, the particle is automatically destroyed.
    # @option opts [Sketchup::Color, Array, String, Fixnum] :color1 ('Gray')
    #   Starting color.
    # @option opts [Sketchup::Color, Array, String, Fixnum] :color2 (nil) Ending
    #   color. Pass nil to have the ending color remain same as the starting
    #   color.
    # @option opts [Numeric] :alpha1 (1.0) Starting opacity, a value between
    #   0.0 and 1.0.
    # @option opts [Numeric] :alpha2 (nil) Ending opacity, a value between 0.0
    #   and 1.0. Pass nil if ending opacity is ought to be the same as the
    #   starting opacity.
    # @option opts [Numeric] :fade (0.0) A time ratio it should take the effect
    #   to fade into the starting opacity and fade out from the ending opacity,
    #   a value between 0.0 and 1.0.
    # @option opts [Fixnum] :lifetime (100) Particle lifetime in frames, a value
    #   greater than zero.
    # @option opts [Fixnum] :num_seg (16) Number of segments the particle is to
    #   consist of, a value between 3 and 120.
    # @option opts [Numeric] :rot_angle (0.0) Rotate angle in degrees.
    # @option opts [Fixnum] :type (1)
    #   1. Defines a 2D circular particle that is drawn through view drawing
    #      functions. This type is fast, but particle shade and shadow is not
    #      present. Also, this particle doesn't blend quite well with other
    #      particles of this type.
    #   2. Defines a 2D circular particle that is created from SketchUp
    #      geometry. This type is normal, and guarantees good, balanced results.
    #   3. Defines a 3D spherical particle that is crated from SketchUp
    #      geometry. This type is slow, but it guarantees best results.
    # @return [nil]
    def create_particle(opts)
      if opts[:type] == 1
        MSPhysics::C::Particle.create(opts, @update_timestep)
        return
      end
      opts2 = {
        :position       => opts[:position] ? Geom::Point3d.new(opts[:position]) : Geom::Point3d.new(0, 0, 0),
        :velocity       => opts[:velocity] ? Geom::Vector3d.new(opts[:velocity]) : nil,
        :velocity_damp  => opts[:velocity_damp] ? AMS.clamp(opts[:velocity_damp].to_f, 0.0, 1.0) : 0.0,
        :gravity        => opts[:gravity] ? Geom::Vector3d.new(opts[:gravity]) : nil,
        :radius         => opts[:radius] ? AMS.clamp(opts[:radius].to_f, 0.01, 10000) : 1.0,
        :scale          => opts[:scale] ? AMS.clamp(opts[:scale].to_f, 0.001, 1000) : 1.01,
        :color1         => opts[:color1] ? Sketchup::Color.new(opts[:color1]) : Sketchup::Color.new('Gray'),
        :color2         => opts[:color2] ? Sketchup::Color.new(opts[:color2]) : nil,
        :alpha1         => opts[:alpha1] ? AMS.clamp(opts[:alpha1].to_f, 0.0, 1.0) : 1.0,
        :alpha2         => opts[:alpha2] ? AMS.clamp(opts[:alpha2].to_f, 0.0, 1.0) : nil,
        :fade           => opts[:fade] ? AMS.clamp(opts[:fade].to_f, 0.0, 1.0) : 0.0,
        :lifetime       => opts[:lifetime] ? AMS.clamp(opts[:lifetime].to_i, 1, nil) : 100,
        :num_seg        => opts[:num_seg] ? AMS.clamp(opts[:num_seg].to_i, 3, 120) : 16,
        :rot_angle      => opts[:rot_angle] ? opts[:rot_angle].to_f.degrees : 0.0,
        :type           => opts[:type] ? AMS.clamp(opts[:type].to_i, 1, 3) : 1
      }
      opts2[:life_start] = @frame
      opts2[:life_end] = @frame + opts2[:lifetime]
      opts2[:color] = Sketchup::Color.new(opts2[:color1])
      opts2[:color].alpha = opts2[:fade].zero? ? opts2[:alpha1] : 0.0
      @particles << opts2
      return if opts2[:type] == 1

      model = Sketchup.active_model
      if opts2[:type] == 3 # 3D entity
        if @particle_def3d[opts2[:num_seg]].nil? || @particle_def3d[opts2[:num_seg]].deleted?
          @particle_def3d[opts2[:num_seg]] = model.definitions.add("AP3D_#{opts2[:num_seg]}")
          e = @particle_def3d[opts2[:num_seg]].entities
          c1 = e.add_circle(ORIGIN, X_AXIS, 1, opts2[:num_seg])
          c2 = e.add_circle([0,0,-10], Z_AXIS, 1, opts2[:num_seg])
          c1.each { |edge| edge.hidden = true }
          f = e.add_face(c1)
          f.followme(c2)
          c2.each { |edge| edge.erase! }
        end
        cd = @particle_def3d[opts2[:num_seg]]
        normal = Geom::Vector3d.new(Math.cos(opts2[:rot_angle]), Math.sin(opts2[:rot_angle]), 0)
      else # 2D entity
        if @particle_def2d[opts2[:num_seg]].nil? || @particle_def2d[opts2[:num_seg]].deleted?
          @particle_def2d[opts2[:num_seg]] = model.definitions.add("MSP_P2D_#{opts2[:num_seg]}")
          e = @particle_def2d[opts2[:num_seg]].entities
          c = e.add_circle(ORIGIN, Z_AXIS, 1, opts2[:num_seg])
          c.each { |edge| edge.hidden = true }
          e.add_face(c)
        end
        cd = @particle_def2d[opts2[:num_seg]]
        eye = model.active_view.camera.eye
        normal = (eye == opts2[:position]) ? Z_AXIS : opts2[:position].vector_to(eye)
      end
      tra1 = Geom::Transformation.new(opts[:position], normal)
      tra2 = Geom::Transformation.rotation(ORIGIN, Z_AXIS, opts[:rot_angle])
      tra3 = Geom::Transformation.scaling(opts[:radius])
      tra = tra1*tra2*tra3
      opts2[:material] = model.materials.add('FX')
      opts2[:material].color = opts2[:color]
      opts2[:material].alpha = opts2[:color].alpha / 255.0
      opts2[:group] = model.entities.add_instance(cd, tra)
      opts2[:group].material = opts2[:material]
      opts2[:group].visible = false unless @particles_visible

      nil
    end

    # Get number of particles.
    # @return [Fixnum]
    def particles_size
      @particles.size + MSPhysics::C::Particle.size
    end

    # Remove all particles.
    def clear_particles
      model = Sketchup.active_model
      mats = model.materials
      @particles.each { |opts|
        next true if opts[:type] == 1
        if opts[:group].valid?
          opts[:group].material = nil
          opts[:group].erase!
        end
        mats.remove(opts[:material]) if mats.respond_to?(:remove)
      }
      @particles.clear
      MSPhysics::C::Particle.destroy_all
    end

    # Show/hide particles.
    # @param [Boolean] state
    # @return [Boolean] success
    def show_particles(state)
      state = state ? true : false
      return false if @particles_visible == state
      @particles_visible = state
      @particles.each { |opts|
        next true if opts[:type] == 1
        opts[:group].visible = state if opts[:group].valid? && opts[:group].visible? != state
      }
      true
    end

    # Determine whether particles are visible.
    # @return [Boolean]
    def particles_visible?
      @particles_visible
    end

    # @!endgroup
    # @!group Curve Interface

    # Get point and vector on curve.
    # @param [String] name Curve name.
    # @param [Numeric] dist Distance on curve in inches.
    # @param [Numeric] loop Whether to loop if given distance extends curve length.
    # @return [Array<(Geom::Point3d, Geom::Vector3d)>] An array of two
    #   values. The first element resembles a point on curve. The second element
    #   resembles a direction on curve.
    # @raise [NameError] if curve with particular name doesn't exist.
    # @example Moving body along curve.
    #   # Assuming that curve named 'CurveA' exists.
    #   onStart {
    #     this.set_static(true)
    #   }
    #   onUpdate {
    #     point, vector = simulation.eval_curve_abs('CurveA', frame * 0.1, true)
    #     this.set_position(point, 1)
    #   }
    def eval_curve_abs(name, dist, loop = true)
      raise(NameError, "Curve named, '#{name}', doesn't exist!", caller) unless curve_exists?(name)
      curve = @curves[name.to_s]
      pts = curve.vertices.map { |x| x.position }
      curve_len = 0.0
      curve.edges.each { |e| curve_len += e.length }
      if loop
        if pts.first != pts.last
          curve_len += pts.first.distance(pts.last)
          pts << pts.first
        end
        dist = dist % curve_len
      else
        if dist > curve_len
          dist = curve_len
        elsif dist < -curve_len
          dist = -curve_len
        end
        dist += curve_len if dist < 0
      end
      cur_dist = 0
      last_dist = 0
      last_pt = pts.first
      for i in 0...pts.length
        cur_dist += last_pt.distance(pts[i])
        if (cur_dist - dist).abs < 1.0e-6
          point = pts[i]
          if loop
            j = i
            k = i == pts.length - 1 ? 1 : i + 1
          else
            j = i == pts.length - 1 ? i - 1 : i
            k = j + 1
          end
          vector = pts[j].vector_to(pts[k]).normalize
          return [point, vector]
        elsif cur_dist > dist
          dir = last_pt.vector_to(pts[i])
          dir.length = dist - last_dist
          point = last_pt + dir
          return [point, last_pt.vector_to(pts[i]).normalize]
        end
        last_pt = pts[i]
        last_dist = cur_dist
      end
      nil
    end

    # Get curve length.
    # @param [String] name Curve name.
    # @return [Numeric] Curve length.
    # @raise [NameError] if curve with particular name doesn't exist.
    def curve_length(name)
      raise(NameError, "Curve named, '#{name}', doesn't exist!", caller) unless curve_exists?(name)
      curve = @curves[name.to_s]
      curve_len = 0.0
      curve.edges.each { |e| curve_len += e.length }
      curve_len
    end

    # Determine whether curve with a particular name exists.
    # @param [String] name Curve name.
    # @return [Boolean]
    def curve_exists?(name)
      if @curves[name.to_s] && @curves[name.to_s].valid?
        true
      else
        load_curves
        @curves[name.to_s] ? true : false
      end
    end

    # @!endgroup
    # @!group Advanced

    # Determine whether the undo command is triggered when simulation resets.
    # @note By default the undo command is not triggered when simulation resets.
    # @return [Boolean]
    def undo_on_reset?
      @undo_on_reset
    end

    # Enable/disable the undo commend when simulation resets, to undo all
    # model changes.
    # @param [Boolean] state
    def undo_on_reset=(state)
      @undo_on_reset = state ? true : false
    end

    # @!endgroup

    private

    def update_joy_data
      @joystick_data.clear
      @joybutton_data.clear
      @joypad_data = 0
      return if MSPhysics::Joystick.get_num_joysticks == 0
      joys = MSPhysics::Joystick.get_open_joysticks
      if joys.empty?
        joy = MSPhysics::Joystick.open(0)
      else
        joy = joys[0]
      end
      return unless joy
      MSPhysics::Joystick.update
      count = MSPhysics::Joystick.get_num_axes(joy)
      names = %w(leftx lefty rightx righty)
      for i in 0...count
        v = MSPhysics::Joystick.get_axis(joy, i)
        r = v < 0 ? v / 32768.0 : v / 32767.0
        @joystick_data[names[i]] = (i == 1 || i == 3) ? -r : r
      end
      count = MSPhysics::Joystick.get_num_buttons(joy)
      names = %w(x a b y lt rt lb rb back start leftb rightb)
      for i in 0...count
        @joybutton_data[names[i]] = MSPhysics::Joystick.get_button(joy, i)
      end
      if MSPhysics::Joystick.get_num_hats(joy) > 0
        @joypad_data = MSPhysics::Joystick.get_hat(joy, 0)
      end
    end

    def load_curves
      @curves.clear
      Sketchup.active_model.entities.grep(Sketchup::Edge).each { |e|
        curve = e.curve
        next if curve.nil?
        name = curve.get_attribute('MSPhysics Curve', 'Name')
        next if !name.is_a?(String) || @curves[name]
        @curves[name] = curve
      }
    end

    def update_particles
      model = Sketchup.active_model
      mats = model.materials
      eye = model.active_view.camera.eye
      MSPhysics::C::Particle.update_all(@update_timestep)
      @particles.reject! { |opts|
        # Control radius
        opts[:radius] *= opts[:scale]
        # Check if need to delete the particle
        if (opts[:type] != 1 && (opts[:group].deleted? || opts[:material].deleted?)) || (opts[:radius] < 0.01 || opts[:radius] > 10000 || @frame >= opts[:life_end] || @frame < opts[:life_start])
          next true if opts[:type] == 1
          if opts[:group].valid?
            opts[:group].material = nil
            opts[:group].erase!
          end
          mats.remove(opts[:material]) if mats.respond_to?(:remove)
          next true
        end
        # Transition color
        ratio = (@frame - opts[:life_start]) / opts[:lifetime].to_f
        if opts[:color2]
          c = opts[:color]
          c1 = opts[:color1]
          c2 = opts[:color2]
          c.red = c1.red + ((c2.red - c1.red) * ratio).to_i
          c.green = c1.green + ((c2.green - c1.green) * ratio).to_i
          c.blue = c1.blue + ((c2.blue - c1.blue) * ratio).to_i
        end
        # Transition opacity
        if opts[:alpha2]
          if opts[:fade].zero?
            opts[:color].alpha = opts[:alpha1] + (opts[:alpha2] - opts[:alpha1]) * ratio
          else
            fh = opts[:fade] * 0.5
            if ratio < fh
              r = (@frame - opts[:life_start]) / (opts[:lifetime] * fh).to_f
              opts[:color].alpha = opts[:alpha1] * r
            elsif ratio >= (1.0 - fh)
              r = (opts[:life_end] - @frame) / (opts[:lifetime] * fh).to_f
              opts[:color].alpha = opts[:alpha2] * r
            else
              fl = opts[:lifetime] * opts[:fade]
              r = (@frame - opts[:life_start] - fl * 0.5) / (opts[:lifetime] - fl).to_f
              opts[:color].alpha = opts[:alpha1] + (opts[:alpha2] - opts[:alpha1]) * r
            end
          end
        else
          if opts[:fade].zero?
            opts[:color].alpha = opts[:alpha1]
          else
            fh = opts[:fade] * 0.5
            if ratio < fh
              r = (@frame - opts[:life_start]) / (opts[:lifetime] * fh).to_f
              opts[:color].alpha = opts[:alpha1] * r
            elsif ratio >= (1.0 - fh)
              r = (opts[:life_end] - @frame) / (opts[:lifetime] * fh).to_f
              opts[:color].alpha = opts[:alpha1] * r
            else
              opts[:color].alpha = opts[:alpha1]
            end
          end
        end
        # Control velocity and position
        pos = opts[:position]
        vel = opts[:velocity]
        if vel
          gra = opts[:gravity]
          if gra
            vel.x += gra.x * @update_timestep
            vel.y += gra.y * @update_timestep
            vel.z += gra.z * @update_timestep
          end
          if opts[:velocity_damp] != 0
            s = 1.0 - opts[:velocity_damp]
            vel.x *= s
            vel.y *= s
            vel.z *= s
          end
          pos.x += vel.x * @update_timestep
          pos.y += vel.y * @update_timestep
          pos.z += vel.z * @update_timestep
        end
        if opts[:type] != 1
          opts[:material].color = opts[:color]
          opts[:material].alpha = opts[:color].alpha / 255.0
          if opts[:type] == 3
            normal = Geom::Vector3d.new(Math.cos(opts[:rot_angle]), Math.sin(opts[:rot_angle]), 0)
          else
            normal = (eye == pos) ? Z_AXIS : pos.vector_to(eye)
          end
          tra1 = Geom::Transformation.new(pos, normal)
          tra2 = Geom::Transformation.rotation(ORIGIN, Z_AXIS, opts[:rot_angle])
          tra3 = Geom::Transformation.scaling(opts[:radius])
          opts[:group].move!(tra1*tra2*tra3)
        end
        false
      }
    rescue Exception => e
      err_message = e.message
      err_backtrace = e.backtrace
      if RUBY_VERSION !~ /1.8/
        err_message.force_encoding("UTF-8")
        err_backtrace.each { |i| i.force_encoding("UTF-8") }
      end
      puts "An exception occurred while updating particles.\n#{e.class}:\n#{err_message}\nTrace:\n#{err_backtrace.join("\n")}"
    end

    def draw_particles(view, bb)
      return unless @particles_visible
      MSPhysics::C::Particle.draw_all(view, bb)
=begin
      eye = view.camera.eye
      fx = {}
      @particles.each { |opts|
        if opts[:type] == 1
          dist = opts[:position].distance(eye)
          fx[dist] = opts
        else
          bb.add(opts[:group].bounds) if opts[:group].valid?
        end
      }
      keys = fx.keys
      keys.sort! { |x,y| y <=> x }
      keys.each { |dist|
        opts = fx[dist]
        normal = (eye == opts[:position]) ? Z_AXIS : opts[:position].vector_to(eye)
        pts = MSPhysics.points_on_circle3d(opts[:position], opts[:radius], normal, opts[:num_seg], opts[:rot_angle].radians)
        bb.add(opts[:position])
        view.drawing_color = opts[:color]
        view.draw(GL_POLYGON, pts)
      }
=end
    rescue Exception => e
      err_message = e.message
      err_backtrace = e.backtrace
      if RUBY_VERSION !~ /1.8/
        err_message.force_encoding("UTF-8")
        err_backtrace.each { |i| i.force_encoding("UTF-8") }
      end
      puts "An exception occurred while drawing particles.\n#{e.class}:\n#{err_message}\nTrace:\n#{err_backtrace.join("\n")}"
    end

    def do_on_update
      if @error
        Simulation.reset
        return
      end
      model = Sketchup.active_model
      view = model.active_view
      cam = view.camera
      # Wait a few frames just to update icons in case of huge performance.
      if @update_wait < 5
        @update_wait += 1
        return
      end
      # Handle simulation play/pause events.
      if @paused
        unless @pause_updated
          @pause_updated = true
          @time_info[:sim] += Time.now - @time_info[:last]
          @fps_info[:change] += Time.now - @fps_info[:last]
          if MSPhysics.sdl_used?
            MSPhysics::Music.pause
            MSPhysics::Sound.pause(-1)
          end
        end
        #view.show_frame
        return
      end
      if @pause_updated
        @time_info[:last] = Time.now
        @fps_info[:last] = Time.now
        @pause_updated = false
        if MSPhysics.sdl_used?
          MSPhysics::Music.resume
          MSPhysics::Sound.resume(-1)
        end
      end
      # Clear drawing queues
      @draw_queue.clear
      @points_queue.clear
      # Update joy data
      update_joy_data
      # Increment frame
      @frame += 1
      # Call onPreUpdate event
      call_event(:onPreUpdate)
      return unless Simulation.is_active?
      # Process thrusters
      @thrusters.reject! { |body, data|
        next true unless body.is_valid?
        value = nil
        begin
          #value = Kernel.eval(data[:controller], @controller.get_binding, CONTROLLER_NAME, 0)
          value = @controller_context.instance_eval(data[:controller], CONTROLLER_NAME, 0)
        rescue Exception => e
          err_message = e.message
          err_message.force_encoding("UTF-8") if RUBY_VERSION !~ /1.8/
          puts "An exception occurred while evaluating thruster controller!\nController:\n#{data[:controller]}\n#{e.class}:\n#{err_message}"
        end
        return unless Simulation.is_active?
        next true unless body.is_valid?
        begin
          if value.is_a?(Numeric)
            value = Geom::Vector3d.new(0, 0, value)
          elsif value.is_a?(Array) && value.size == 3 && value.x.is_a?(Numeric) && value.y.is_a?(Numeric) && value.z.is_a?(Numeric)
            value = Geom::Vector3d.new(value)
          else
            next
          end
          if value.length != 0
            value = AMS.scale_vector(value, 1.0/@update_timestep)
            body.add_force2( data[:lock_axis] ? value.transform(body.get_normal_matrix) : value )
          end
        rescue Exception => e
          err_message = e.message
          err_message.force_encoding("UTF-8") if RUBY_VERSION !~ /1.8/
          puts "An exception occurred while assigning thruster controller!\nController:\n#{data[:controller]}\n#{e.class}:\n#{err_message}"
        end
        false
      }
      # Process emitters
      @emitters.reject! { |body, data|
        next true unless body.is_valid?
        value = nil
        begin
          #value = Kernel.eval(data[:controller], @controller.get_binding, CONTROLLER_NAME, 0)
          value = @controller_context.instance_eval(data[:controller], CONTROLLER_NAME, 0)
        rescue Exception => e
          err_message = e.message
          err_message.force_encoding("UTF-8") if RUBY_VERSION !~ /1.8/
          puts "An exception occurred while evaluating emitter controller!\nController:\n#{data[:controller]}\n#{e.class}:\n#{err_message}"
        end
        return unless Simulation.is_active?
        next true unless body.is_valid?
        begin
          if value.is_a?(Numeric)
            value = Geom::Vector3d.new(0, 0, value)
          elsif value.is_a?(Array) && value.size == 3 && value.x.is_a?(Numeric) && value.y.is_a?(Numeric) && value.z.is_a?(Numeric)
            value = Geom::Vector3d.new(value)
          else
            next
          end
          if value.length != 0
            value = AMS.scale_vector(value, 1.0/@update_timestep)
            if @frame % data[:rate] == 0
              self.emit_body(body, data[:lock_axis] ? value.transform(body.get_normal_matrix) : value, data[:lifetime])
            end
          end
        rescue Exception => e
          err_message = e.message
          err_message.force_encoding("UTF-8") if RUBY_VERSION !~ /1.8/
          puts "An exception occurred while assigning emitter controller!\nController:\n#{data[:controller]}\n#{e.class}:\n#{err_message}"
        end
        false
      }
      # Disable object validation while processing data to improve performance.
      world_address = @world.get_address
      ovs = MSPhysics::Newton.is_object_validation_enabled?
      MSPhysics::Newton.enable_object_validation(false)
      # Process buoyancy planes
      @buoyancy_planes.reject! { |entity, data|
        next true unless entity.valid?
        tra = entity.transformation
        body_address = MSPhysics::Newton::World.get_first_body(world_address)
        while body_address
          unless MSPhysics::Newton::Body.is_static?(body_address)
            MSPhysics::Newton::Body.apply_buoyancy(body_address, tra.origin, tra.zaxis, data[:current].transform(tra), data[:density], data[:viscosity], data[:viscosity])
          end
          body_address = MSPhysics::Newton::World.get_next_body(world_address, body_address)
        end
        false
      }
      # Update controlled joints
      @controlled_joints.reject! { |joint, data|
        next true if !joint.valid?
        if data.is_a?(Array)
          controller = data[0]
          ratio = data[1]
        else
          controller = data
          ratio = 1
        end
        value = nil
        begin
          value = @controller_context.instance_eval(controller, CONTROLLER_NAME, 0)
        rescue Exception => e
          err_message = e.message
          err_message.force_encoding("UTF-8") if RUBY_VERSION !~ /1.8/
          puts "An exception occurred while evaluating joint controller!\nController:\n#{controller}\n#{e.class}:\n#{err_message}"
        end
        return unless Simulation.is_active?
        next true if !joint.valid?
        begin
          if joint.is_a?(Servo) || joint.is_a?(Piston) || joint.is_a?(CurvyPiston)
            if value.is_a?(Numeric)
              joint.controller = value * ratio
            elsif value.nil?
              joint.controller = nil
            end
          elsif joint.is_a?(UpVector)
            if (value.is_a?(Array) || value.is_a?(Geom::Vector3d)) && value.x.is_a?(Numeric) && value.y.is_a?(Numeric) && value.z.is_a?(Numeric)
              joint.set_pin_dir(value)
            end
          elsif value.is_a?(Numeric)
            joint.controller = value * ratio
          end
        rescue Exception => e
          err_message = e.message
          err_message.force_encoding("UTF-8") if RUBY_VERSION !~ /1.8/
          puts "An exception occurred while assigning joint controller!\nController:\n#{controller}\n#{e.class}:\n#{err_message}"
        end
        false
      }
      # Update transformations of all transformed entities.
      # Update newton world
      @world.update(@update_timestep, @update_rate)
      body_address = MSPhysics::Newton::World.get_first_body(world_address)
      while body_address
        if MSPhysics::Newton::Body.matrix_changed?(body_address)
          data = MSPhysics::Newton::Body.get_user_data(body_address)
          if data.is_a?(MSPhysics::Body) && data.get_group.valid?
            data.get_group.move!(data.get_matrix)
          end
        end
        body_address = MSPhysics::Newton::World.get_next_body(world_address, body_address)
      end
      # Re-enable object validation.
      MSPhysics::Newton.enable_object_validation(ovs)
      # Call onTouch event
      count = MSPhysics::Newton::World.get_touch_data_count(world_address)
      for i in 0...count
        data = MSPhysics::Newton::World.get_touch_data_at(world_address, i)
        body1 = MSPhysics::Newton::Body.get_user_data(data[0])
        body2 = MSPhysics::Newton::Body.get_user_data(data[1])
        if body1.is_a?(MSPhysics::Body) && body2.is_a?(MSPhysics::Body)
          begin
            body1.call_event(:onTouch, body2, data[2], data[3], data[4], data[5])
          rescue Exception => e
            abort(e)
          end
          return unless Simulation.is_active?
        end
      end
      # Call onTouching event
      count = MSPhysics::Newton::World.get_touching_data_count(world_address)
      for i in 0...count
        data = MSPhysics::Newton::World.get_touching_data_at(world_address, i)
        body1 = MSPhysics::Newton::Body.get_user_data(data[0])
        body2 = MSPhysics::Newton::Body.get_user_data(data[1])
        if body1.is_a?(MSPhysics::Body) && body2.is_a?(MSPhysics::Body)
          begin
            body1.call_event(:onTouching, body2)
          rescue Exception => e
            abort(e)
          end
          return unless Simulation.is_active?
        end
      end
      # Call onUntouch event
      count = MSPhysics::Newton::World.get_untouch_data_count(world_address)
      for i in 0...count
        data = MSPhysics::Newton::World.get_untouch_data_at(world_address, i)
        body1 = MSPhysics::Newton::Body.get_user_data(data[0])
        body2 = MSPhysics::Newton::Body.get_user_data(data[1])
        if body1.is_a?(MSPhysics::Body) && body2.is_a?(MSPhysics::Body)
          begin
            body1.call_event(:onUntouch, body2)
          rescue Exception => e
            abort(e)
          end
          return unless Simulation.is_active?
        end
      end
      # Update particles
      update_particles
      # Call onUpdate event
      call_event(:onUpdate)
      return unless Simulation.is_active?
      # Call onPostUpdate event
      call_event(:onPostUpdate)
      return unless Simulation.is_active?
      # Process 3D sounds.
      if MSPhysics.sdl_used?
        MSPhysics::Sound.update_effects
      end
      # Process emitted bodies.
      @emitted_bodies.reject! { |body, life_end|
        next false if life_end == 0 || @frame < life_end
        if body.is_valid?
          @created_entities.delete(body.get_group)
          body.destroy(true)
        end
        true
      }
      # Update camera
      ent = @camera[:follow]
      if ent
        if ent.deleted?
          @camera[:follow] = nil
        else
          eye = ent.bounds.center + @camera[:offset]
          tar = eye + cam.direction.to_a
          cam.set(eye, tar, [0,0,1])
        end
      end
      ent = @camera[:target]
      if ent
        if ent.deleted?
          @camera[:target] = nil
        else
         dir = cam.eye.vector_to(ent.bounds.center)
         cam.set(cam.eye, dir, [0,0,1])
        end
      end
      # Process dragged body
      unless @picked.empty?
        if @picked[0].is_valid?
          pick_pt = @picked[1].transform(@picked[0].get_matrix)
          dest_pt = @picked[2]
          MSPhysics::Newton::Body.apply_pick_and_drag(@picked[0].get_address, pick_pt, dest_pt, 120.0 / @update_rate, 20.0 / @update_rate)
          #Newton::Body.apply_pick_and_drag2(@picked[0].get_address, pick_pt, dest_pt, 0.3, 0.95, @update_timestep)
        else
          @picked.clear
          set_cursor(@original_cursor_id)
        end
      end
      # Update FPS
      if @frame % @fps_info[:update_rate] == 0
        @fps_info[:change] += Time.now - @fps_info[:last]
        @fps = ( @fps_info[:change] == 0 ? 0 : (@fps_info[:update_rate] / @fps_info[:change]).round )
        @fps_info[:last] = Time.now
        @fps_info[:change] = 0
      end
      # Update status bar text
      update_status_text
      # Update Scenes
      if @scene_selected_time
        r = AMS.clamp((Time.now - @scene_selected_time) / @scene_transition_time, 0 , 1)
        #r = 0.5 * Math.sin((r - 0.5) * Math::PI) + 0.5
        @scene_data1.transition(@scene_data2, r)
        if r == 1.0
          @scene_data1 = nil
          @scene_data2 = nil
          @scene_selected_time = nil
          @scene_transition_time = nil
        end
      end
      # Record replay animation
      if MSPhysics::Replay.record_enabled?
        MSPhysics::Replay.record_all(@frame)
      end
      # Redraw view
      view.show_frame
    end

    def draw_contact_points(view)
      return unless @contact_points[:show]
      world_address = @world.get_address
      ovs = MSPhysics::Newton.is_object_validation_enabled?
      MSPhysics::Newton.enable_object_validation(false)
      body_address = MSPhysics::Newton::World.get_first_body(world_address)
      while body_address
        points = MSPhysics::Newton::Body.get_contact_points(body_address, true)
        if points.size > 0
          view.draw_points(points, @contact_points[:point_size], @contact_points[:point_style], @contact_points[:point_color])
        end
        body_address = MSPhysics::Newton::World.get_next_body(world_address, body_address)
      end
      MSPhysics::Newton.enable_object_validation(ovs)
    end

    def draw_contact_forces(view)
      return unless @contact_forces[:show]
      view.drawing_color = @contact_forces[:line_color]
      view.line_width = @contact_forces[:line_width]
      view.line_stipple = @contact_forces[:line_stipple]
      world_address = @world.get_address
      ovs = MSPhysics::Newton.is_object_validation_enabled?
      MSPhysics::Newton.enable_object_validation(false)
      body_address = MSPhysics::Newton::World.get_first_body(world_address)
      while body_address
        mass = MSPhysics::Newton::Body.get_mass(body_address)
        if mass > 0
          MSPhysics::Newton::Body.get_contacts(body_address, false).each { |contact|
            for i in 0..2
              x = contact[3][i] / mass.to_f
              next if x.abs < 1
              pt = contact[1].clone
              pt[i] += x
              view.draw(GL_LINES, [contact[1], pt])
            end
          }
        end
        body_address = MSPhysics::Newton::World.get_next_body(world_address, body_address)
      end
      MSPhysics::Newton.enable_object_validation(ovs)
    end

    def draw_collision_wireframe(view)
      return unless @collision_wireframe[:show]
      MSPhysics::Newton::World.draw_collision_wireframe(@world.get_address, view, @bb, @collision_wireframe[:sleeping], @collision_wireframe[:active], @collision_wireframe[:line_width], @collision_wireframe[:line_stipple])
=begin
      view.line_width = @collision_wireframe[:line_width]
      view.line_stipple = @collision_wireframe[:line_stipple]
      world_address = @world.get_address
      ovs = MSPhysics::Newton.is_object_validation_enabled?
      MSPhysics::Newton.enable_object_validation(false)
      body_address = MSPhysics::Newton::World.get_first_body(world_address)
      while body_address
        sleeping = MSPhysics::Newton::Body.is_sleeping?(body_address)
        view.drawing_color = @collision_wireframe[sleeping ? :sleeping : :active]
        MSPhysics::Newton::Body.get_collision_faces(body_address).each { |face|
          view.draw(GL_LINE_LOOP, face)
        }
        body_address = MSPhysics::Newton::World.get_next_body(world_address, body_address)
      end
      MSPhysics::Newton.enable_object_validation(ovs)
=end
    end

    def draw_axes(view)
      return unless @axes[:show]
      view.line_width = @axes[:line_width]
      view.line_stipple = @axes[:line_stipple]
      world_address = @world.get_address
      ovs = MSPhysics::Newton.is_object_validation_enabled?
      MSPhysics::Newton.enable_object_validation(false)
      body_address = MSPhysics::Newton::World.get_first_body(world_address)
      while body_address
        pos = MSPhysics::Newton::Body.get_position(body_address, 1)
        tra = MSPhysics::Newton::Body.get_matrix(body_address)
        # Draw xaxis
        l = tra.xaxis
        l.length = @axes[:size]
        pt = pos + l
        view.drawing_color = @axes[:xaxis]
        view.draw_line(pos, pt)
        # Draw yaxis
        l = tra.yaxis
        l.length = @axes[:size]
        pt = pos + l
        view.drawing_color = @axes[:yaxis]
        view.draw_line(pos, pt)
        # Draw zaxis
        l = tra.zaxis
        l.length = @axes[:size]
        pt = pos + l
        view.drawing_color = @axes[:zaxis]
        view.draw_line(pos, pt)
        # Get next body
        body_address = MSPhysics::Newton::World.get_next_body(world_address, body_address)
      end
      MSPhysics::Newton.enable_object_validation(ovs)
    end

    def draw_aabb(view)
      return unless @aabb[:show]
      view.drawing_color = @aabb[:line_color]
      view.line_width = @aabb[:line_width]
      view.line_stipple = @aabb[:line_stipple]
      world_address = @world.get_address
      ovs = MSPhysics::Newton.is_object_validation_enabled?
      MSPhysics::Newton.enable_object_validation(false)
      body_address = MSPhysics::Newton::World.get_first_body(world_address)
      while body_address
        min, max = MSPhysics::Newton::Body.get_aabb(body_address)
        view.draw(GL_LINE_LOOP, [min, [min.x, max.y, min.z], [max.x, max.y, min.z], [max.x, min.y, min.z]])
        view.draw(GL_LINE_LOOP, [[min.x, min.y, max.z], [min.x, max.y, max.z], max, [max.x, min.y, max.z]])
        view.draw(GL_LINES, [min, [min.x, min.y, max.z], [min.x, max.y, min.z], [min.x, max.y, max.z], [max.x, max.y, min.z], max, [max.x, min.y, min.z], [max.x, min.y, max.z]])
        body_address = MSPhysics::Newton::World.get_next_body(world_address, body_address)
      end
      MSPhysics::Newton.enable_object_validation(ovs)
    end

    def draw_pick_and_drag(view)
      return if @picked.empty?
      if @picked[0].is_valid?
        pt1 = @picked[1].transform(@picked[0].get_matrix)
        pt2 = @picked[2]
        @bb.add(pt2)
        view.line_width = @pick_and_drag[:line_width]
        view.line_stipple = @pick_and_drag[:line_stipple]
        view.drawing_color = @pick_and_drag[:line_color]
        view.draw_line(pt1, pt2)
        view.line_stipple = ''
        view.draw_points(pt1, @pick_and_drag[:point_size], @pick_and_drag[:point_style], @pick_and_drag[:point_color])
        if AMS::Keyboard.shift_down?
          view.line_width = @pick_and_drag[:vline_width]
          view.line_stipple = @pick_and_drag[:vline_stipple]
          view.drawing_color = @pick_and_drag[:vline_color]
          view.draw(GL_LINES, [pt2.x, pt2.y, 0], pt2)
        end
      else
        @picked.clear
        set_cursor(@original_cursor_id)
      end
    end

    def draw_queues(view)
      @draw_queue.each { |type, points, color, width, stipple, mode|
        view.drawing_color = color
        view.line_width = width
        view.line_stipple = stipple
        if mode == 1
          @bb.add(points)
          view.draw(type, points)
        else
          view.draw2d(type, points)
        end
      }
      @points_queue.each{ |points, size, style, color, width, stipple|
        @bb.add(points)
        view.line_width = width
        view.line_stipple = stipple
        view.draw_points(points, size, style, color)
      }
    rescue Exception => e
      @draw_queue.clear
      @points_queue.clear
    end

    def update_status_text
      if @mouse_over && !@suspended
        change = @fps.zero? ? 0 : (1000.0/@fps).round
        Sketchup.status_text = "Frame: #{@frame}   Time: #{sprintf("%.2f", @world.get_time)} s   FPS: #{@fps}   Change: #{change} ms   Thread Count: #{@world.get_cur_threads_count}   #{@mode == 0 ? @interactive_note : @game_note}   #{@general_note}"
      end
    end

    def call_event(evt, *args)
      return if @world.nil? || !@world.is_valid?
      @world.get_bodies.each { |body|
        next if !body.is_valid?
        body.call_event(evt, *args)
        return if @world.nil? || !@world.is_valid?
      }
    rescue Exception => e
      abort(e)
    end

    def call_event2(evt, *args)
      return if @world.nil? || !@world.is_valid?
      @world.get_bodies.each { |body|
        next if !body.is_valid?
        body.call_event(evt, *args)
        return if @world.nil? || !@world.is_valid?
      }
    rescue Exception => e
      @error = e
    end

    def abort(e)
      @error = e
      Simulation.reset
    end

    def init_joint(joint_ent, parent_body, child_body, pin_matrix)
      jdict = 'MSPhysics Joint'
      jtype = joint_ent.get_attribute(jdict, 'Type')
      attr = joint_ent.get_attribute(jdict, 'Angle Units', MSPhysics::DEFAULT_ANGLE_UNITS)
      ang_ratio = attr == 'deg' ? 1.degrees : 1
      iang_ratio = 1.0 / ang_ratio
      attr = joint_ent.get_attribute(jdict, 'Position Units', MSPhysics::DEFAULT_POSITION_UNITS)
      pos_ratio = case attr
        when 'mm'
          0.001
        when 'cm'
          0.01
        when 'dm'
          0.1
        when 'm'
          1.0
        when 'in'
          0.0254
        when 'ft'
          0.3048
        when 'yd'
          0.9144
        else
          1.0
      end
      ipos_ratio = 1.0 / pos_ratio
      case jtype
      when 'Fixed'
        attr = joint_ent.get_attribute(jdict, 'Adjust To', 0)
        if (attr == 2 && parent_body)
          centre = parent_body.get_position(1)
          pin_matrix = Geom::Transformation.new(pin_matrix.xaxis, pin_matrix.yaxis, pin_matrix.zaxis, centre)
        elsif (attr == 1)
          centre = child_body.get_position(1)
          pin_matrix = Geom::Transformation.new(pin_matrix.xaxis, pin_matrix.yaxis, pin_matrix.zaxis, centre)
        end
        joint = MSPhysics::Fixed.new(@world, parent_body, pin_matrix)
      when 'Hinge'
        joint = MSPhysics::Hinge.new(@world, parent_body, pin_matrix)
        attr = joint_ent.get_attribute(jdict, 'Min', MSPhysics::Hinge::DEFAULT_MIN * iang_ratio)
        joint.min = attr.to_f * ang_ratio
        attr = joint_ent.get_attribute(jdict, 'Max', MSPhysics::Hinge::DEFAULT_MAX * iang_ratio)
        joint.max = attr.to_f * ang_ratio
        attr = joint_ent.get_attribute(jdict, 'Enable Limits', MSPhysics::Hinge::DEFAULT_LIMITS_ENABLED)
        joint.limits_enabled = attr
        attr = joint_ent.get_attribute(jdict, 'Friction', MSPhysics::Hinge::DEFAULT_FRICTION)
        joint.friction = attr.to_f
        attr = joint_ent.get_attribute(jdict, 'Accel', MSPhysics::Hinge::DEFAULT_ACCEL)
        joint.accel = attr.to_f
        attr = joint_ent.get_attribute(jdict, 'Damp', MSPhysics::Hinge::DEFAULT_DAMP)
        joint.damp = attr.to_f
        attr = joint_ent.get_attribute(jdict, 'Enable Rotate Back', MSPhysics::Hinge::DEFAULT_ROTATE_BACK_ENABLED)
        joint.rotate_back_enabled = attr
        attr = joint_ent.get_attribute(jdict, 'Enable Strong Mode', MSPhysics::Hinge::DEFAULT_STRONG_MODE_ENABLED)
        joint.strong_mode_enabled = attr
        attr = joint_ent.get_attribute(jdict, 'Start Angle', MSPhysics::Hinge::DEFAULT_START_ANGLE * iang_ratio)
        joint.start_angle = attr.to_f * ang_ratio
        controller = joint_ent.get_attribute(jdict, 'Controller')
        if controller.is_a?(String) && !controller.empty?
          @controlled_joints[joint] = controller
        end
      when 'Motor'
        joint = MSPhysics::Motor.new(@world, parent_body, pin_matrix)
        attr = joint_ent.get_attribute(jdict, 'Accel', MSPhysics::Motor::DEFAULT_ACCEL)
        joint.accel = attr.to_f
        attr = joint_ent.get_attribute(jdict, 'Damp', MSPhysics::Motor::DEFAULT_DAMP)
        joint.damp = attr.to_f
        attr = joint_ent.get_attribute(jdict, 'Enable Free Rotate', MSPhysics::Motor::DEFAULT_FREE_ROTATE_ENABLED)
        joint.free_rotate_enabled = attr
        controller = joint_ent.get_attribute(jdict, 'Controller')
        if controller.is_a?(String) && !controller.empty?
          @controlled_joints[joint] = controller
        end
      when 'Servo'
        joint = MSPhysics::Servo.new(@world, parent_body, pin_matrix)
        attr = joint_ent.get_attribute(jdict, 'Min', MSPhysics::Servo::DEFAULT_MIN * iang_ratio)
        joint.min = attr.to_f * ang_ratio
        attr = joint_ent.get_attribute(jdict, 'Max', MSPhysics::Servo::DEFAULT_MAX * iang_ratio)
        joint.max = attr.to_f * ang_ratio
        attr = joint_ent.get_attribute(jdict, 'Enable Limits', MSPhysics::Servo::DEFAULT_LIMITS_ENABLED)
        joint.limits_enabled = attr
        attr = joint_ent.get_attribute(jdict, 'Rate', MSPhysics::Servo::DEFAULT_RATE * iang_ratio)
        joint.rate = attr.to_f * ang_ratio
        attr = joint_ent.get_attribute(jdict, 'Power', MSPhysics::Servo::DEFAULT_POWER)
        joint.power = attr.to_f
        attr = joint_ent.get_attribute(jdict, 'Reduction Ratio', MSPhysics::Servo::DEFAULT_REDUCTION_RATIO)
        joint.reduction_ratio = attr.to_f
        controller = joint_ent.get_attribute(jdict, 'Controller')
        if controller.is_a?(String) && !controller.empty?
          @controlled_joints[joint] = [controller, ang_ratio]
        end
      when 'Slider'
        joint = MSPhysics::Slider.new(@world, parent_body, pin_matrix)
        attr = joint_ent.get_attribute(jdict, 'Min', MSPhysics::Slider::DEFAULT_MIN * ipos_ratio)
        joint.min = attr.to_f * pos_ratio
        attr = joint_ent.get_attribute(jdict, 'Max', MSPhysics::Slider::DEFAULT_MAX * ipos_ratio)
        joint.max = attr.to_f * pos_ratio
        attr = joint_ent.get_attribute(jdict, 'Enable Limits', MSPhysics::Slider::DEFAULT_LIMITS_ENABLED)
        joint.limits_enabled = attr
        attr = joint_ent.get_attribute(jdict, 'Friction', MSPhysics::Slider::DEFAULT_FRICTION)
        joint.friction = attr.to_f
        controller = joint_ent.get_attribute(jdict, 'Controller')
        if controller.is_a?(String) && !controller.empty?
          @controlled_joints[joint] = controller
        end
      when 'Piston'
        joint = MSPhysics::Piston.new(@world, parent_body, pin_matrix)
        attr = joint_ent.get_attribute(jdict, 'Min', MSPhysics::Piston::DEFAULT_MIN * ipos_ratio)
        joint.min = attr.to_f * pos_ratio
        attr = joint_ent.get_attribute(jdict, 'Max', MSPhysics::Piston::DEFAULT_MAX * ipos_ratio)
        joint.max = attr.to_f * pos_ratio
        attr = joint_ent.get_attribute(jdict, 'Enable Limits', MSPhysics::Piston::DEFAULT_LIMITS_ENABLED)
        joint.limits_enabled = attr
        attr = joint_ent.get_attribute(jdict, 'Rate', MSPhysics::Piston::DEFAULT_RATE * ipos_ratio)
        joint.rate = attr.to_f * pos_ratio
        attr = joint_ent.get_attribute(jdict, 'Power', MSPhysics::Piston::DEFAULT_POWER)
        joint.power = attr.to_f
        attr = joint_ent.get_attribute(jdict, 'Reduction Ratio', MSPhysics::Piston::DEFAULT_REDUCTION_RATIO)
        joint.reduction_ratio = attr.to_f
        controller = joint_ent.get_attribute(jdict, 'Controller')
        if controller.is_a?(String) && !controller.empty?
          @controlled_joints[joint] = [controller, pos_ratio]
        end
      when 'Spring'
        joint = MSPhysics::Spring.new(@world, parent_body, pin_matrix)
        attr = joint_ent.get_attribute(jdict, 'Min', MSPhysics::Spring::DEFAULT_MIN * ipos_ratio)
        joint.min = attr.to_f * pos_ratio
        attr = joint_ent.get_attribute(jdict, 'Max', MSPhysics::Spring::DEFAULT_MAX * ipos_ratio)
        joint.max = attr.to_f * pos_ratio
        attr = joint_ent.get_attribute(jdict, 'Accel', MSPhysics::Spring::DEFAULT_ACCEL)
        joint.accel = attr.to_f
        attr = joint_ent.get_attribute(jdict, 'Damp', MSPhysics::Spring::DEFAULT_DAMP)
        joint.damp = attr.to_f
        attr = joint_ent.get_attribute(jdict, 'Enable Limits', MSPhysics::Spring::DEFAULT_LIMITS_ENABLED)
        joint.limits_enabled = attr
        attr = joint_ent.get_attribute(jdict, 'Enable Strong Mode', MSPhysics::Spring::DEFAULT_STRONG_MODE_ENABLED)
        joint.strong_mode_enabled = attr
        attr = joint_ent.get_attribute(jdict, 'Start Position', MSPhysics::Spring::DEFAULT_START_POSITION * ipos_ratio)
        joint.start_position = attr.to_f * pos_ratio
        controller = joint_ent.get_attribute(jdict, 'Controller')
        if controller.is_a?(String) && !controller.empty?
          @controlled_joints[joint] = controller
        end
      when 'UpVector'
        joint = MSPhysics::UpVector.new(@world, parent_body, pin_matrix)
        attr = joint_ent.get_attribute(jdict, 'Accel', MSPhysics::UpVector::DEFAULT_ACCEL)
        joint.accel = attr.to_f
        attr = joint_ent.get_attribute(jdict, 'Damp', MSPhysics::UpVector::DEFAULT_DAMP)
        joint.damp = attr.to_f
        attr = joint_ent.get_attribute(jdict, 'Enable Damper', MSPhysics::UpVector::DEFAULT_DAMPER_ENABLED)
        joint.damper_enabled = attr
        controller = joint_ent.get_attribute(jdict, 'Controller')
        if controller.is_a?(String) && !controller.empty?
          @controlled_joints[joint] = controller
        end
      when 'Corkscrew'
        joint = MSPhysics::Corkscrew.new(@world, parent_body, pin_matrix)
        attr = joint_ent.get_attribute(jdict, 'Min Position', MSPhysics::Corkscrew::DEFAULT_MIN_POSITION * ipos_ratio)
        joint.min_position = attr.to_f * pos_ratio
        attr = joint_ent.get_attribute(jdict, 'Max Position', MSPhysics::Corkscrew::DEFAULT_MAX_POSITION * ipos_ratio)
        joint.max_position = attr.to_f * pos_ratio
        attr = joint_ent.get_attribute(jdict, 'Enable Linear Limits', MSPhysics::Corkscrew::DEFAULT_LINEAR_LIMITS_ENABLED)
        joint.linear_limits_enabled = attr
        attr = joint_ent.get_attribute(jdict, 'Linear Friction', MSPhysics::Corkscrew::DEFAULT_LINEAR_FRICTION)
        joint.linear_friction = attr.to_f
        attr = joint_ent.get_attribute(jdict, 'Min Angle', MSPhysics::Corkscrew::DEFAULT_MIN_ANGLE * iang_ratio)
        joint.min_angle = attr.to_f * ang_ratio
        attr = joint_ent.get_attribute(jdict, 'Max Angle', MSPhysics::Corkscrew::DEFAULT_MAX_ANGLE * iang_ratio)
        joint.max_angle = attr.to_f * ang_ratio
        attr = joint_ent.get_attribute(jdict, 'Enable Angular Limits', MSPhysics::Corkscrew::DEFAULT_ANGULAR_LIMITS_ENABLED)
        joint.angular_limits_enabled = attr
        attr = joint_ent.get_attribute(jdict, 'Angular Friction', MSPhysics::Corkscrew::DEFAULT_ANGULAR_FRICTION)
        joint.angular_friction = attr.to_f
      when 'BallAndSocket'
        joint = MSPhysics::BallAndSocket.new(@world, parent_body, pin_matrix)
        attr = joint_ent.get_attribute(jdict, 'Max Cone Angle', MSPhysics::BallAndSocket::DEFAULT_MAX_CONE_ANGLE * iang_ratio)
        joint.max_cone_angle = attr.to_f * ang_ratio
        attr = joint_ent.get_attribute(jdict, 'Enable Cone Limits', MSPhysics::BallAndSocket::DEFAULT_CONE_LIMITS_ENABLED)
        joint.cone_limits_enabled = attr
        attr = joint_ent.get_attribute(jdict, 'Min Twist Angle', MSPhysics::BallAndSocket::DEFAULT_MIN_TWIST_ANGLE * iang_ratio)
        joint.min_twist_angle = attr.to_f * ang_ratio
        attr = joint_ent.get_attribute(jdict, 'Max Twist Angle', MSPhysics::BallAndSocket::DEFAULT_MAX_TWIST_ANGLE * iang_ratio)
        joint.max_twist_angle = attr.to_f * ang_ratio
        attr = joint_ent.get_attribute(jdict, 'Enable Twist Limits', MSPhysics::BallAndSocket::DEFAULT_TWIST_LIMITS_ENABLED)
        joint.twist_limits_enabled = attr
        attr = joint_ent.get_attribute(jdict, 'Friction', MSPhysics::BallAndSocket::DEFAULT_FRICTION)
        joint.friction = attr.to_f
        controller = joint_ent.get_attribute(jdict, 'Controller')
        if controller.is_a?(String) && !controller.empty?
          @controlled_joints[joint] = controller
        end
      when 'Universal'
        joint = MSPhysics::Universal.new(@world, parent_body, pin_matrix)
        attr = joint_ent.get_attribute(jdict, 'Min1', MSPhysics::Universal::DEFAULT_MIN * iang_ratio)
        joint.min1 = attr.to_f * ang_ratio
        attr = joint_ent.get_attribute(jdict, 'Max1', MSPhysics::Universal::DEFAULT_MAX * iang_ratio)
        joint.max1 = attr.to_f * ang_ratio
        attr = joint_ent.get_attribute(jdict, 'Enable Limits1', MSPhysics::Universal::DEFAULT_LIMITS_ENABLED)
        joint.limits1_enabled = attr
        attr = joint_ent.get_attribute(jdict, 'Min2', MSPhysics::Universal::DEFAULT_MIN * iang_ratio)
        joint.min2 = attr.to_f * ang_ratio
        attr = joint_ent.get_attribute(jdict, 'Max2', MSPhysics::Universal::DEFAULT_MAX * iang_ratio)
        joint.max2 = attr.to_f * ang_ratio
        attr = joint_ent.get_attribute(jdict, 'Enable Limits2', MSPhysics::Universal::DEFAULT_LIMITS_ENABLED)
        joint.limits2_enabled = attr
        attr = joint_ent.get_attribute(jdict, 'Friction', MSPhysics::Universal::DEFAULT_FRICTION)
        joint.friction = attr.to_f
        controller = joint_ent.get_attribute(jdict, 'Controller')
        if controller.is_a?(String) && !controller.empty?
          @controlled_joints[joint] = controller
        end
      when 'CurvySlider', 'CurvyPiston'
        if jtype == 'CurvySlider'
          joint = MSPhysics::CurvySlider.new(@world, parent_body, pin_matrix)
          attr = joint_ent.get_attribute(jdict, 'Enable Alignment', MSPhysics::CurvySlider::DEFAULT_ALIGNMENT_ENABLED)
          joint.alignment_enabled = attr
          attr = joint_ent.get_attribute(jdict, 'Enable Rotation', MSPhysics::CurvySlider::DEFAULT_ROTATION_ENABLED)
          joint.rotation_enabled = attr
          attr = joint_ent.get_attribute(jdict, 'Enable Loop', MSPhysics::CurvySlider::DEFAULT_LOOP_ENABLED)
          joint.loop_enabled = attr
          attr = joint_ent.get_attribute(jdict, 'Linear Friction', MSPhysics::CurvySlider::DEFAULT_LINEAR_FRICTION)
          joint.linear_friction = attr.to_f
          attr = joint_ent.get_attribute(jdict, 'Angular Friction', MSPhysics::CurvySlider::DEFAULT_ANGULAR_FRICTION)
          joint.angular_friction = attr.to_f
          controller = joint_ent.get_attribute(jdict, 'Controller')
          if controller.is_a?(String) && !controller.empty?
            @controlled_joints[joint] = controller
          end
        else
          joint = MSPhysics::CurvyPiston.new(@world, parent_body, pin_matrix)
          attr = joint_ent.get_attribute(jdict, 'Enable Alignment', MSPhysics::CurvyPiston::DEFAULT_ALIGNMENT_ENABLED)
          joint.alignment_enabled = attr
          attr = joint_ent.get_attribute(jdict, 'Enable Rotation', MSPhysics::CurvyPiston::DEFAULT_ROTATION_ENABLED)
          joint.rotation_enabled = attr
          attr = joint_ent.get_attribute(jdict, 'Enable Loop', MSPhysics::CurvyPiston::DEFAULT_LOOP_ENABLED)
          joint.loop_enabled = attr
          attr = joint_ent.get_attribute(jdict, 'Angular Friction', MSPhysics::CurvyPiston::DEFAULT_ANGULAR_FRICTION)
          joint.angular_friction = attr.to_f
          attr = joint_ent.get_attribute(jdict, 'Rate', MSPhysics::CurvyPiston::DEFAULT_RATE * ipos_ratio)
          joint.rate = attr.to_f * pos_ratio
          attr = joint_ent.get_attribute(jdict, 'Power', MSPhysics::CurvyPiston::DEFAULT_POWER)
          joint.power = attr.to_f
          attr = joint_ent.get_attribute(jdict, 'Reduction Ratio', MSPhysics::CurvyPiston::DEFAULT_REDUCTION_RATIO)
          joint.reduction_ratio = attr.to_f
          controller = joint_ent.get_attribute(jdict, 'Controller')
          if controller.is_a?(String) && !controller.empty?
            @controlled_joints[joint] = controller
          end
        end
        # Get points on curve
        closest_dist = nil
        start_vertex = nil
        MSPhysics::Group.get_entities(joint_ent).each { |e|
          next unless e.is_a?(Sketchup::Edge)
          dist1 = e.start.position.distance(ORIGIN)
          dist2 = e.end.position.distance(ORIGIN)
          if dist1 < dist2
            vertex = e.start
            dist = dist1
          else
            vertex = e.end
            dist = dist2
          end
          if closest_dist.nil? || dist < closest_dist
            closest_dist = dist
            start_vertex = vertex
            break if closest_dist < 1.0e-8
          end
        }
        verts = []
        if start_vertex
          used_edges = []
          verts << start_vertex
          edge = start_vertex.edges[0]
          verts << edge.other_vertex(start_vertex)
          used_edges << edge
          while true
            edge = nil
            lastv = verts.last
            lastv.edges.each { |e|
              unless used_edges.include?(e)
                edge = e
                break
              end
            }
            break unless edge
            verts << edge.other_vertex(lastv)
            used_edges << edge
          end
        end
        # Append points to curve
        tra = joint_ent.transformation
        if parent_body
          tra = parent_body.get_matrix * tra
        end
        verts.each { |v| joint.add_point(v.position.transform(tra)) }
      else
        return
      end

      attr = joint_ent.get_attribute(jdict, 'Constraint Type', MSPhysics::Joint::DEFAULT_CONSTRAINT_TYPE).to_i
      joint.constraint_type = attr
      attr = joint_ent.name.to_s
      attr = joint_ent.get_attribute(jdict, 'ID').to_s if attr.empty?
      joint.name = attr
      attr = joint_ent.get_attribute(jdict, 'Stiffness', MSPhysics::Joint::DEFAULT_STIFFNESS)
      joint.stiffness = attr.to_f
      attr = joint_ent.get_attribute(jdict, 'Bodies Collidable', MSPhysics::Joint::DEFAULT_BODIES_COLLIDABLE)
      joint.bodies_collidable = attr
      attr = joint_ent.get_attribute(jdict, 'Breaking Force', MSPhysics::Joint::DEFAULT_BREAKING_FORCE)
      joint.breaking_force = attr.to_f

      joint.connect(child_body)
      joint
    end

    def init_joints
      Sketchup.active_model.entities.each { |ent|
        next if !ent.is_a?(Sketchup::Group) && !ent.is_a?(Sketchup::ComponentInstance)
        type = ent.get_attribute('MSPhysics', 'Type', 'Body')
        if type == 'Body'
          next if ent.get_attribute('MSPhysics Body', 'Ignore', false) || get_body_by_group(ent).nil?
          cents = ent.is_a?(Sketchup::ComponentInstance) ? ent.definition.entities : ent.entities
          parent_body = get_body_by_group(ent)
          ptra = ent.transformation
          cents.each { |cent|
            next if ((!cent.is_a?(Sketchup::Group) && !cent.is_a?(Sketchup::ComponentInstance)) ||
              cent.get_attribute('MSPhysics', 'Type', 'Body') != 'Joint')
            jtra = ptra * MSPhysics::Geometry.extract_matrix_scale(cent.transformation)
            MSPhysics::JointConnectionTool.get_connected_bodies(cent, ent, true)[0].each { |child_ent|
              child_body = get_body_by_group(child_ent)
              begin
                init_joint(cent, parent_body, child_body, jtra)
              rescue Exception => e
                err_message = e.message
                err_backtrace = e.backtrace
                if RUBY_VERSION !~ /1.8/
                  err_message.force_encoding("UTF-8")
                  err_backtrace.each { |i| i.force_encoding("UTF-8") }
                end
                puts "An exception occurred while creating a joint from #{cent}!\n#{e.class}:\n#{err_message}\nTrace:\n#{err_backtrace.join("\n")}"
              end
            }
          }
        elsif type == 'Joint'
          jtra = MSPhysics::Geometry.extract_matrix_scale(ent.transformation)
          MSPhysics::JointConnectionTool.get_connected_bodies(ent, nil, true)[0].each { |child_ent|
            child_body = get_body_by_group(child_ent)
            begin
              init_joint(ent, nil, child_body, jtra)
            rescue Exception => e
              err_message = e.message
              err_backtrace = e.backtrace
              if RUBY_VERSION !~ /1.8/
                err_message.force_encoding("UTF-8")
                err_backtrace.each { |i| i.force_encoding("UTF-8") }
              end
              puts "An exception occurred while creating a joint from #{ent}!\n#{e.class}:\n#{err_message}\nTrace:\n#{err_backtrace.join("\n")}"
            end
          }
        end
      }
=begin
      Sketchup.active_model.entities.each { |ent|
        next if !ent.is_a?(Sketchup::Group) && !ent.is_a?(Sketchup::ComponentInstance)
        next if ent.get_attribute('MSPhysics', 'Type', 'Body') != 'Body'
        body = get_body_by_group(ent)
        next unless body
        jdata = MSPhysics::JointConnectionTool.get_connected_joints(ent, true)[0]
        jdata.each { |jent, jparent_ent, jtra|
          begin
            jparent_body = jparent_ent ? get_body_by_group(jparent_ent) : nil
            init_joint(jent, jparent_body, body, jtra)
          rescue Exception => e
            err_message = e.message
            err_backtrace = e.backtrace
            if RUBY_VERSION !~ /1.8/
              err_message.force_encoding("UTF-8")
              err_backtrace.each { |i| i.force_encoding("UTF-8") }
            end
            puts "An exception occurred while creating a joint from #{jent}!\n#{e.class}:\n#{err_message}\nTrace:\n#{err_backtrace.join("\n")}"
          end
        }
      }
=end
    end

    public

    # @!visibility private

    # SketchUp Tool Events

    def activate
      model = Sketchup.active_model
      view = model.active_view
      camera = view.camera
      default_sim = MSPhysics::DEFAULT_SIMULATION_SETTINGS
      default_buoyancy = MSPhysics::DEFAULT_BUOYANCY_PLANE_SETTINGS
      # Close active path
      state = true
      while state
        state = model.close_active
      end
      # Wrap operations
      if Sketchup.version.to_i > 6
        model.start_operation('MSPhysics Simulation', true)
      else
        model.start_operation('MSPhysics Simulation')
      end
      # Clear selection
      model.selection.clear
      # Stop any running animation
      view.animation = nil
      # Stop any playing sounds and music
      if MSPhysics.sdl_used?
        MSPhysics::Sound.destroy_all
        MSPhysics::Music.destroy_all
      end
      # Save selected page
      @selected_page = model.pages.selected_page
      # Save camera orientation
      @camera[:original] = [
        camera.eye,
        camera.target,
        camera.up,
        camera.perspective?,
        camera.aspect_ratio,
        camera.description,
      ]
      # To avoid a warning temporarily enable the perspective mode.
      t = camera.perspective?
      camera.perspective = true
      @camera[:original].concat [
        camera.focal_length,
        camera.fov,
        camera.image_width
      ]
      # To avoid a warning temporarily enable the parallel projection mode.
      camera.perspective = false
      # Set and save original perspective
      @camera[:original] << camera.height
      camera.perspective = t
      # Save rendering options
      model.rendering_options.each { |k, v| @rendering_options[k] = v }
      # Save shadow info
      model.shadow_info.each { |k, v| @shadow_info[k] = v }
      # Save layer visibility
      model.layers.each { |l| @layers[l] = l.visible? }
      # Activate observer
      AMS::Sketchup.add_observer(self)
      # Configure Settings
      settings = MSPhysics::Settings
      @update_rate = settings.get_update_rate
      @update_timestep = settings.get_update_timestep
      # Create world
      @world = MSPhysics::World.new(settings.get_world_scale)
      @world.set_solver_model(settings.get_solver_model)
      @world.set_friction_model(settings.get_friction_model)
      @world.set_gravity([0, 0, settings.get_gravity])
      @world.set_material_thickness(settings.get_material_thickness)
      #~ @world.set_max_threads_count(@world.get_max_threads_count) # Threads are disabled, so changing thread count won't make a difference.
      @world.set_max_threads_count(1)
      @world.set_contact_merge_tolerance(default_sim[:contact_merge_tolerance])
      destructor = Proc.new {
        Simulation.reset
      }
      MSPhysics::Newton::World.set_destructor_proc(@world.get_address, destructor)
      # Enable Newton object validation
      MSPhysics::Newton.enable_object_validation(true)
      # Add entities
      ents = model.entities.to_a
      ents.each { |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        next unless entity.valid?
        type = entity.get_attribute('MSPhysics', 'Type', 'Body')
        if type == 'Body'
          next if entity.get_attribute('MSPhysics Body', 'Ignore')
          begin
            body = add_group(entity)
          rescue MSPhysics::ScriptException => e
            abort(e)
            return
          rescue StandardError => e
            index = ents.index(entity)
            err_message = e.message
            err_backtrace = e.backtrace
            if RUBY_VERSION !~ /1.8/
              err_message.force_encoding("UTF-8")
              err_backtrace.each { |i| i.force_encoding("UTF-8") }
            end
            #~ puts "Entity at index #{index} was not added to simulation:\n#{e.class}:\n#{err_message}\nTrace:\n#{err_backtrace.join("\n")}\n\n"
            puts "Entity at index #{index} was not added to simulation:\n#{e.class}:\n#{err_message}\n\n"
          end
        elsif type == 'Joint'
        elsif type == 'Buoyancy Plane'
          dict = 'MSPhysics Buoyancy Plane'
          density = entity.get_attribute(dict, 'Density')
          density = default_buoyancy[:density] unless density.is_a?(Numeric)
          viscosity = entity.get_attribute(dict, 'Viscosity')
          viscosity = default_buoyancy[:viscosity] unless viscosity.is_a?(Numeric)
          current_x = entity.get_attribute(dict, 'Current X')
          current_x = default_buoyancy[:current_x] unless current_x.is_a?(Numeric)
          current_y = entity.get_attribute(dict, 'Current Y')
          current_y = default_buoyancy[:current_y] unless current_y.is_a?(Numeric)
          current_z = entity.get_attribute(dict, 'Current Z')
          current_z = default_buoyancy[:current_z] unless current_z.is_a?(Numeric)
          @buoyancy_planes[entity] = {
            :density => AMS.clamp(density, 0.001, nil),
            :viscosity => AMS.clamp(viscosity, 0, 1),
            :current => Geom::Vector3d.new(current_x, current_y, current_z)
          }
        end
        return unless @world
      }
      # Create Joints
      init_joints
      # Apply settings
      MSPhysics::Settings.apply_settings
      # Open MIDI device
      AMS::MIDI.open_device
      # Initialize timers
      @time_info[:start] = Time.now
      @time_info[:last] = Time.now
      @fps_info[:last] = Time.now
      @timers_started = true
      # Camera follow and track from scenes
      page = model.pages.selected_page
      if page
        desc = page.description.downcase
        sentences = desc.split('.')
        sentences.each { |sentence|
          words = sentence.split(' ')
          if words.size >= 3 && words[0] == 'camera'
            if words[1] == 'follow'
              ent = get_group_by_name(words[2])
              if ent
                @camera[:follow] = ent
                @camera[:offset] = view.camera.eye - ent.bounds.center
              end
            elsif words[1] == 'track'
              ent = get_group_by_name(words[2])
              @camera[:target] = ent if ent
            end
          end
        }
      end
      # Call onStart event
      call_event(:onStart)
      # Refresh view
      view.invalidate
      # Start the update timer
      if Simulation.is_active?
        #@update_timer = AMS::Timer.start(0, true){ do_on_update }
        @update_timer = ::UI.start_timer(0, true) { do_on_update }
      end
    end

    def deactivate(view)
      model = Sketchup.active_model
      camera = view.camera
      # Stop any running animation
      view.animation = nil
      # Stop the update timer
      if @update_timer
        #AMS::Timer.stop(@update_timer)
        ::UI.stop_timer(@update_timer)
        @update_timer = nil
      end
      # Call onEnd event
      orig_error = @error
      call_event(:onEnd)
      @error = orig_error if orig_error
      # Set time end
      end_time = Time.now
      # Destroy all emitted bodies
      destroy_all_emitted_bodies
      # Destroy world
      @world.destroy if @world.is_valid?
      @world = nil
      # Erase log-line and display-note
      if @lltext[:ent] != nil && @lltext[:ent].valid?
        @lltext[:ent].material = nil
        @lltext[:ent].erase!
      end
      if @lltext[:mat] != nil && @lltext[:mat].valid? && model.materials.respond_to?(:remove)
        model.materials.remove(@lltext[:mat])
      end
      @lltext.clear
      if @dntext[:ent] != nil && @dntext[:ent].valid?
        @dntext[:ent].material = nil
        @dntext[:ent].erase!
      end
      if @dntext[:mat] != nil && @dntext[:mat].valid? && model.materials.respond_to?(:remove)
        model.materials.remove(@dntext[:mat])
      end
      @dntext.clear
      # Reset entity transformations
      @saved_transformations.each { |e, t|
        e.move!(t) if e.valid?
      }
      @saved_transformations.clear
      # Show hidden entities
      @hidden_entities.each { |e|
        e.visible = true if e.valid?
      }
      @hidden_entities.clear
      # Remove particles
      clear_particles
      # Undo changed style made by the show collision function
      show_collision_wireframe(false)
      # Show cursor if hidden
      AMS::Cursor.show(true)
      # Close control panel
      MSPhysics::ControlPanel.show(false)
      MSPhysics::ControlPanel.remove_sliders
      # Clear variables of the common context
      MSPhysics::Common.clear_variables
      # Remove observer
      AMS::Sketchup.remove_observer(self)
      # Purge unused
      model.definitions.purge_unused
      #~ model.materials.purge_unused
      # Reset selected page
      if @selected_page && @selected_page.valid?
        tt = @selected_page.transition_time
        @selected_page.transition_time = 0
        model.pages.selected_page = @selected_page
        @selected_page.transition_time = tt
        @selected_page = nil
      end
      # Set camera to original placement
      opts = @camera[:original]
      camera.set(opts[0], opts[1], opts[2])
      camera.aspect_ratio = opts[4]
      camera.description = opts[5]
      # Enable the perspective mode to avoid a warning
      camera.perspective = true
      camera.focal_length = opts[6]
      camera.fov = opts[7]
      camera.image_width = opts[8]
      # Enable the parallel projection mode to avoid a warning
      camera.perspective = false
      camera.height = opts[9]
      # Set original perspective
      camera.perspective = opts[3]
      # Reset rendering options
      @rendering_options.each { |k, v| model.rendering_options[k] = v }
      @rendering_options.clear
      # Reset shadow info
      @shadow_info.each { |k, v| model.shadow_info[k] = v }
      @shadow_info.clear
      # Reset layer visibility
      @layers.each { |l, s| l.visible = s if l.valid? && l.visible? != s }
      @layers.clear
      # Clear selection
      model.selection.clear
      # Make sure the undo called next will not undo the prior operation.
      model.entities.add_cpoint(ORIGIN).erase!
      # Finish all operations
      model.commit_operation
      # Undo all changes
      Sketchup.undo if @undo_on_reset
      # Refresh view
      view.invalidate
      # Close joystick
      MSPhysics::Joystick.close_all_joysticks
      # Destroy all particles
      MSPhysics::C::Particle.destroy_all
      # Stop any playing sounds and music
      if MSPhysics.sdl_used?
        MSPhysics::Sound.destroy_all
        MSPhysics::Music.destroy_all
      end
      # Close MIDI device
      AMS::MIDI.close_device
      # Free some variables
      @controller_context = nil
      @emitters.clear
      @thrusters.clear
      @buoyancy_planes.clear
      @controlled_joints.clear
      @scene_data1 = nil
      @scene_data2 = nil
      @scene_selected_time = nil
      @scene_transition_time = nil
      @cc_bodies.clear
      @particles.clear
      @particle_def2d.clear
      @particle_def3d.clear
      @curves.clear
      @@instance = nil
      # Show info
      if @error
        err_message = @error.message
        err_backtrace = @error.backtrace
        if RUBY_VERSION !~ /1.8/
          err_message.force_encoding("UTF-8")
          err_backtrace.each { |i| i.force_encoding("UTF-8") }
        end
        msg = "MSPhysics Simulation has been aborted due to an error!\n#{@error.class}:\n#{err_message}"
        puts "#{msg}\nTrace:\n#{err_backtrace.join("\n")}\n\n"
        ::UI.messagebox(msg)
        if @error.is_a?(MSPhysics::ScriptException)
          MSPhysics::Dialog.locate_error(@error)
        end
      elsif @timers_started
        @time_info[:end] = end_time
        @time_info[:total] = @time_info[:end] - @time_info[:start]
        @time_info[:sim] += @time_info[:end] - @time_info[:last] unless @paused
        average_fps = (@time_info[:sim].zero? ? 0 : (@frame / @time_info[:sim]).round)
        puts 'MSPhysics Simulation Results:'
        printf("  frames          : %d\n", @frame)
        printf("  average FPS     : %d\n", average_fps)
        printf("  simulation time : %.2f seconds\n", @time_info[:sim])
        printf("  total time      : %.2f seconds\n\n", @time_info[:total])
      else
        puts "MSPhysics Simulation was stopped before it even started."
      end
      # Save replay animation data
      if MSPhysics::Replay.recorded_data_valid? && ::UI.messagebox("Would you like to save recorded simulation for the replay?", MB_YESNO) == IDYES
        MSPhysics::Replay.save_recorded_data
        if ::UI.messagebox("Would you like to smoothen recorded camera?", MB_YESNO) == IDYES
          MSPhysics::Replay.smooth_camera_data1(25)
        end
        MSPhysics::Replay.save_data_to_model(true)
      end
      MSPhysics::Replay.clear_recorded_data
      # Start garbage collection
      ::ObjectSpace.garbage_collect
    end

    def onCancel(reason, view)
      Simulation.reset
    end

    def resume(view)
      @suspended = false
      if @camera[:follow] && @camera[:follow].valid?
        @camera[:offset] = view.camera.eye - @camera[:follow].bounds.center
      end
      update_status_text
      view.invalidate
    end

    def suspend(view)
      @suspended = true
    end

    def onMouseEnter(view)
      @mouse_over = true
    end

    def onMouseLeave(view)
      @mouse_over = false
    end

    def onMouseMove(flags, x, y, view)
      @cursor_pos = [x,y]
      call_event(:onMouseMove, x, y) unless @paused
      return unless Simulation.is_active?
      @ip.pick(view, x, y)
      return if @ip == @ip1
      @ip1.copy! @ip
      # view.tooltip = @ip1.tooltip
      return if @picked.empty?
      if @mode == 1
        @picked.clear
        set_cursor(@original_cursor_id)
        return
      end
      if @picked[0].is_valid?
        begin
          @picked[0].call_event(:onDrag) if @picked[4] != @frame
        rescue Exception => e
          abort(e)
          return
        end
        return unless Simulation.is_active?
        @picked[4] = @frame
      else
        @picked.clear
        set_cursor(@original_cursor_id)
        return
      end
      cam = view.camera
      line = [cam.eye, @ip1.position]
      if AMS::Keyboard.shift_down?
        normal = view.camera.zaxis
        normal.z = 0
        normal.normalize!
      else
        normal = Z_AXIS
      end
      plane = [@picked[2], normal]
      vector = cam.eye.vector_to(@ip1.position)
      theta = vector.angle_between(normal).radians
      if (90 - theta).abs > 1
        pt = Geom.intersect_line_plane(line, plane)
        v = cam.eye.vector_to(pt)
        @picked[2] = pt if cam.zaxis.angle_between(v).radians < 90
      end
      #~ @picked[2] = @ip1.position
    end

    def onLButtonDown(flags, x, y, view)
      sel = Sketchup.active_model.selection
      if @paused
        sel.clear
        return
      end
      @ip1.pick(view, x, y)
      unless @ip1.valid?
        sel.clear
        return
      end
      pos = @ip1.position
      # Use ray test as it determines positions more accurate than input point.
      ray = view.pickray(x,y)
      res = view.model.raytest(ray)
      if res
        pos = res[0]
        ent = res[1][0]
      else
        ph = view.pick_helper
        ph.do_pick(x,y)
        ent = ph.best_picked
      end
      unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
        sel.clear
        return
      end
      body = get_body_by_group(ent)
      return unless body
=begin
      # Correct input point position if is not located on the picked entity.
      # 1. Transform input point position relative to the deepest element
      # coordinate system.
      path = ph.path_at(0)[0..-2]
      path.each { |e|
        pos.transform!(e.transformation.inverse)
      }
      deepest = ph.leaf_at(0)
      # 2. Verify that input point is located on the picked entity. If point
      # is not on the entity, then use deepest element position as the new
      # reference to the point.
      case deepest
      when Sketchup::ConstructionPoint
        pos = deepest.position
      when Sketchup::Edge
        unless MSPhysics::Geometry.is_point_on_edge?(pos, deepest)
          pos = MSPhysics::Geometry.calc_edge_centre(deepest)
        end
      when Sketchup::Face
        unless MSPhysics::Geometry.is_point_on_face?(pos, deepest)
          pos = MSPhysics::Geometry.calc_face_centre(deepest)
        end
      end
      # 3. Transform input point back into global coordinate system for
      # implementation.
      path.reverse.each { |e|
        pos.transform!(e.transformation)
      }
=end
      # Call the onClick event.
      begin
        @clicked = body
        @clicked.call_event(:onClick, pos.clone)
      rescue Exception => e
        abort(e)
        return
      end
      return unless Simulation.is_active?
      # Pick body if the body is not static.
      return if body.is_static? || @mode == 1
      pick_pt = pos.transform(body.get_matrix.inverse)
      cc = body.get_continuous_collision_state
      body.set_continuous_collision_state(true)
      @picked = [body, pick_pt, pos, cc, nil, sel.include?(ent)]
      sel.add(ent)
      @original_cursor_id = @cursor_id
      set_cursor(MSPhysics::CURSORS[:grab])
      view.lock_inference
    end

    def onLButtonUp(flags, x, y, view)
      unless @picked.empty?
        if @picked[0].is_valid?
          @picked[0].set_continuous_collision_state(@picked[3])
          view.model.selection.remove(@picked[0].get_group) unless @picked[5]
        end
        @picked.clear
        set_cursor(@original_cursor_id)
      end
      begin
        @clicked.call_event(:onUnclick)
      rescue Exception => e
        abort(e)
      end if @clicked and @clicked.is_valid?
      @clicked = nil
    end

    def getMenu(menu)
      @menu_entered2 = true

      menu.add_item(@paused ? 'Play' : 'Pause') {
        self.toggle_play
      }
      menu.add_item('Reset') {
        Simulation.reset
      }

      model = Sketchup.active_model
      view = model.active_view
      sel = model.selection
      ph = view.pick_helper
      ph.do_pick *@cursor_pos
      ent = ph.best_picked
      return unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
      menu.add_separator
      sel.add(ent)
      item = menu.add_item('Camera Follow') {
        next unless ent.valid?
        if @camera[:follow] == ent
          @camera[:follow] = nil
        else
          @camera[:follow] = ent
          @camera[:offset] = view.camera.eye - ent.bounds.center
        end
      }
      menu.set_validation_proc(item) {
        @camera[:follow] == ent ? MF_CHECKED : MF_UNCHECKED
      }
      item = menu.add_item('Camera Target'){
        next unless ent.valid?
        if @camera[:target] == ent
          @camera[:target] = nil
        else
          @camera[:target] = ent
        end
      }
      menu.set_validation_proc(item) {
        @camera[:target] == ent ? MF_CHECKED : MF_UNCHECKED
      }
      item = menu.add_item('Camera Follow and Target') {
        next unless ent.valid?
        if @camera[:follow] == ent && @camera[:target] == ent
          @camera[:follow] = nil
          @camera[:target] = nil
          @camera[:follow] = nil
        else
          @camera[:follow] = ent
          @camera[:target] = ent
          @camera[:offset] = view.camera.eye - ent.bounds.center
        end
      }
      menu.set_validation_proc(item) {
        @camera[:follow] == ent && @camera[:target] == ent ? MF_CHECKED : MF_UNCHECKED
      }
      if @camera[:target] != nil || @camera[:follow] != nil
        menu.add_item('Camera Clear') {
          @camera[:follow] = nil
          @camera[:target] = nil
        }
      end

      body = get_body_by_group(ent)
      return unless body
      menu.add_separator
      menu.add_item('Freeze Body') {
        next unless body.is_valid?
        body.set_frozen(true)
      }
    end

    def onSetCursor
      ::UI.set_cursor(@cursor_id)
    end

    def getInstructorContentDirectory
    end

    def getExtents
      if Sketchup.version.to_i > 6
        Sketchup.active_model.entities.each { |e|
          next if e.is_a?(Sketchup::Text)
          @bb.add(e.bounds) if e.visible?
        }
      end
      wb = @world.get_aabb if @world != nil && @world.is_valid?
      @bb.add(wb) if wb
      @bb
    end

    def draw(view)
      return if @error
      @bb.clear
      draw_contact_points(view)
      draw_contact_forces(view)
      draw_collision_wireframe(view)
      draw_axes(view)
      draw_aabb(view)
      draw_pick_and_drag(view)
      draw_particles(view, @bb)
      draw_queues(view)
      return unless Simulation.is_active?
      view.drawing_color = 'black'
      view.line_width = 5
      view.line_stipple = ''
      call_event2(:onDraw, view, @bb)
    end

    # AMS SketchUp Observer

    def swo_activate
    end

    def swo_deactivate
      Simulation.reset
    end


    def swo_on_post_enter_menu
      @menu_entered = true
    end

    def swo_on_post_exit_menu
      @menu_entered = false
      if @menu_entered2
        sel = Sketchup.active_model.selection
        sel.clear
        sel.add @camera[:follow] if @camera[:follow] && @camera[:follow].valid?
        sel.add @camera[:target] if @camera[:target] && @camera[:target].valid?
        @menu_entered2 = false
      end
    end

    def swo_on_page_selected(page1, page2)
      if page2.transition_time == 0
        @scene_data1 = nil
        @scene_data2 = nil
        @scene_selected_time = nil
        @scene_transition_time = nil
      end
      model = Sketchup.active_model
      model.active_view.animation = nil
      @scene_data1 = MSPhysics::SceneData.new()
      @scene_data2 = MSPhysics::SceneData.new(page2)
      @scene_selected_time = Time.now
      dtt = model.options['PageOptions']['TransitionTime']
      @scene_transition_time = page2.transition_time < 0 ? dtt : page2.transition_time
    end

    def swp_on_key_down(key, val, char)
      return if @menu_entered
      case key
        when 'escape'
          Simulation.reset
          return
        when 'pause'
          toggle_play
      end
      call_event(:onKeyDown, key, val, char) unless @paused
      1
    end

    def swp_on_key_extended(key, val, char)
      return if @menu_entered
      call_event(:onKeyExtended, key, val, char) unless @paused
      1
    end

    def swp_on_key_up(key, val, char)
      return if @menu_entered
      call_event(:onKeyUp, key, val, char) unless @paused
      1
    end


    def swp_on_lbutton_down(x,y)
      call_event(:onLButtonDown, x, y) unless @paused
      0
    end

    def swp_on_lbutton_up(x,y)
      call_event(:onLButtonUp, x, y) unless @paused
      0
    end

    def swp_on_lbutton_double_click(x,y)
      call_event(:onLButtonDoubleClick, x, y) unless @paused
      0
    end


    def swp_on_rbutton_down(x,y)
      call_event(:onRButtonDown, x, y) unless @paused
      # Prevent the menu from showing up if user selects anything, other than
      # simulation bodies.
      if @mode == 0 and !@suspended
        ph = Sketchup.active_model.active_view.pick_helper
        ph.do_pick x,y
        ent = ph.best_picked
        return 1 unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
        return get_body_by_group(ent) ? 0 : 1
      end
      @mode
    end

    def swp_on_rbutton_up(x,y)
      call_event(:onRButtonUp, x, y) unless @paused
      @mode
    end

    def swp_on_rbutton_double_click(x,y)
      call_event(:onRButtonDoubleClick, x, y) unless @paused
      @mode
    end


    def swp_on_mbutton_down(x,y)
      call_event(:onMButtonDown, x, y) unless @paused
      @mode
    end

    def swp_on_mbutton_up(x,y)
      call_event(:onMButtonUp, x, y) unless @paused
      @mode
    end

    def swp_on_mbutton_double_click(x,y)
      call_event(:onMButtonDoubleClick, x, y) unless @paused
      @mode
    end


    def swp_on_xbutton1_down(x,y)
      call_event(:onXButton1Down, x, y) unless @paused
      0
    end

    def swp_on_xbutton1_up(x,y)
      call_event(:onXButton1Up, x, y) unless @paused
      0
    end

    def swp_on_xbutton1_double_click(x,y)
      call_event(:onXButton1DoubleClick, x, y) unless @paused
      0
    end


    def swp_on_xbutton2_down(x,y)
      call_event(:onXButton2Down, x, y) unless @paused
      0
    end

    def swp_on_xbutton2_up(x,y)
      call_event(:onXButton2Up, x, y) unless @paused
      0
    end

    def swp_on_xbutton2_double_click(x,y)
      call_event(:onXButton2DoubleClick, x, y) unless @paused
      0
    end


    def swp_on_mouse_wheel_rotate(x,y, dir)
      call_event(:onMouseWheelRotate, x, y, dir) unless @paused
      @mode
    end

    def swp_on_mouse_wheel_tilt(x,y, dir)
      call_event(:onMouseWheelTilt, x, y, dir) unless @paused
      0
    end

  end # class Simulation
end # module MSPhysics
