require 'MSPhysics.rb'

unless defined?(MSPhysics)
  msg = 'You cannot load MSPhysics extension until SketchUp meets all the plugin compatibility demands!'
  raise(LoadError, msg, caller)
end

dir = File.dirname(__FILE__)
dir.force_encoding("UTF-8") if RUBY_VERSION !~ /1.8/
ops = (RUBY_PLATFORM =~ /mswin|mingw/i) ? 'win' : 'mac'
bit = (Sketchup.respond_to?('is_64bit?') && Sketchup.is_64bit?) ? '64' : '32'
ver = RUBY_VERSION[0..2]
ext = (RUBY_PLATFORM =~ /mswin|mingw/i) ? '.so' : '.bundle'

# Load SDL and SDL Mixer DLLs
use_sdl = true
libraries = %w(libogg libvorbis libogg-0 libvorbis-0 libvorbisfile-3 libmikmod-2 libmodplug-1 SDL2 SDL2_mixer smpeg2 libFLAC-8)
info = ""
libraries.each { |name|
  path = File.join(dir, ops+bit, name + '.dll')
  res = AMS::DLL.load_library(path)
  use_sdl = false if res == nil || res == 0
  info << "#{name} - #{res}\n"
}
# Uncomment to see results of the loaded libraries.
#UI.messagebox info

# Load MSPhysics Library

require File.join(dir, ops+bit, ver, (use_sdl ? 'msp_lib' : 'msp_lib_no_sdl') + ext)

require File.join(dir, 'geometry.rb')
require File.join(dir, 'group.rb')
require File.join(dir, 'collision.rb')
require File.join(dir, 'contact.rb')
require File.join(dir, 'hit.rb')
require File.join(dir, 'script_exception.rb')
require File.join(dir, 'common.rb')
require File.join(dir, 'controller.rb')
require File.join(dir, 'body.rb')
require File.join(dir, 'world.rb')
require File.join(dir, 'material.rb')
require File.join(dir, 'materials.rb')
require File.join(dir, 'joint.rb')
require File.join(dir, 'joint_hinge.rb')
require File.join(dir, 'joint_motor.rb')
require File.join(dir, 'joint_servo.rb')
require File.join(dir, 'joint_corkscrew.rb')
require File.join(dir, 'joint_ball_and_socket.rb')
require File.join(dir, 'joint_universal.rb')
require File.join(dir, 'joint_slider.rb')
require File.join(dir, 'joint_piston.rb')
require File.join(dir, 'joint_spring.rb')
require File.join(dir, 'joint_up_vector.rb')
require File.join(dir, 'joint_fixed.rb')
require File.join(dir, 'joint_curvy_slider.rb')
require File.join(dir, 'joint_curvy_piston.rb')
require File.join(dir, 'simulation.rb')
require File.join(dir, 'settings.rb')
require File.join(dir, 'dialog.rb')
require File.join(dir, 'control_panel.rb')
require File.join(dir, 'joint_tool.rb')
require File.join(dir, 'joint_connection_tool.rb')
require File.join(dir, 'replay.rb')
require File.join(dir, 'scene_data.rb')

# @since 1.0.0
module MSPhysics

  DEFAULT_SIMULATION_SETTINGS = {
    :solver_model           => 0,
    :friction_model         => 0,
    :update_rate            => 2,
    :update_timestep        => 1/60.0,
    :gravity                => [0.0, 0.0, -9.8],
    :material_thickness     => 0.0001,
    :contact_merge_tolerance=> 0.001,
    :world_scale            => 1
  }

  DEFAULT_BODY_SETTINGS = {
    :shape                  => 'Compound',
    :material_name          => 'Default',
    :density                => 700,
    :mass                   => 1.0,
    :static_friction        => 0.90,
    :dynamic_friction       => 0.50,
    :enable_friction        => true,
    :elasticity             => 0.40,
    :softness               => 0.10,
    :linear_damping         => 0.10,
    :angular_damping        => 0.10,
    :magnet_force           => 0.00,
    :magnet_range           => 0.00,
    :magnetic               => false,
    :enable_script          => true,
    :static                 => false,
    :frozen                 => false,
    :collidable             => true,
    :auto_sleep             => true,
    :continuous_collision   => false,
    :thruster_lock_axis     => true,
    :enable_thruster        => true,
    :emitter_lock_axis      => true,
    :emitter_rate           => 10,
    :emitter_lifetime       => 100,
    :enable_emitter         => true,
    :enable_gravity         => true,
    :connect_closest_joints => false
  }

  DEFAULT_BUOYANCY_PLANE_SETTINGS = {
    :density                => 997.04,
    :viscosity              => 0.005,
    :current_x              => 0,
    :current_y              => 0,
    :current_z              => 0,
    :plane_size             => 10000,
    :color                  => Sketchup::Color.new(40,60,220),
    :alpha                  => 0.7,
    :material_name          => 'MSPhysics Buoyancy'
  }

  SCRIPT_NAME = 'MSPhysics Script'.freeze
  CONTROLLER_NAME = 'MSPhysics Controller'.freeze

  CURSORS = {
    :select                 => 0,
    :select_plus            => 0,
    :select_minus           => 0,
    :select_plus_minus      => 0,
    :hand                   => 0,
    :grab                   => 0,
    :target                 => 0
  }

  CURSOR_ORIGINS = {
    :select                 => [3,6],
    :select_plus            => [3,6],
    :select_minus           => [3,6],
    :select_plus_minus      => [3,6],
    :hand                   => [3,6],
    :grab                   => [3,6],
    :target                 => [15,15]
  }

  EMBEDDED_MUSIC_FORMATS = %w(wav aiff riff ogg voc flac mod it xm s3m m4a 669 med mp3 mp2 mid pat).freeze
  EMBEDDED_SOUND_FORMATS = %w(wav aiff riff ogg voc mp3 mp2).freeze

  JOINT_TYPES = {
    #:none               => 0,
    :hinge              => 1,
    :motor              => 2,
    :servo              => 3,
    :slider             => 4,
    :piston             => 5,
    :up_vector          => 6,
    :spring             => 7,
    :corkscrew          => 8,
    :ball_and_socket    => 9,
    :universal          => 10,
    :fixed              => 11,
    :curvy_slider       => 12,
    :curvy_piston       => 13
  }.freeze

  JOINT_NAMES = %w(hinge motor servo slider piston up_vector spring corkscrew ball_and_socket universal fixed curvy_slider curvy_piston).freeze

  DEFAULT_JOINT_SCALE = 1.0

  WATERMARK_COLOR = Sketchup::Color.new(126, 42, 168)

  DEFAULT_ANGLE_UNITS = 'deg'
  DEFAULT_POSITION_UNITS = 'cm'

  EPSILON = 1.0e-6

  class << self

    # Get common attribute value from a collection of entities.
    # @param [Array<Sketchup::Entity>] ents A collection of entities.
    # @param [String] handle Dictionary name.
    # @param [String] name Attribute name.
    # @param [Object] default_value The value to return if the attribute value
    #   is not found.
    # @return [Object] A common attribute value or nil if one of the entity
    #   attributes is different from another.
    def get_attribute(ents, handle, name, default_value = nil)
      vset = false
      value = nil
      ents.each { |e|
        v = e.get_attribute(handle, name, default_value)
        if vset
          return nil if v != value
        else
          value = v
          vset = true
        end
      }
      return value
    end

    # Assign attribute value to a collection of entities.
    # @param [Array<Sketchup::Entity>] ents A collection of entities.
    # @param [String] handle Dictionary name.
    # @param [String] name Attribute name.
    # @param [Object] value Attribute value.
    # @return [void]
    def set_attribute(ents, handle, name, value)
      ents.each { |e|
        e.set_attribute(handle, name, value)
      }
    end

    # Delete attribute value from a collection of entities.
    # @param [Array<Sketchup::Entity>] ents A collection of entities.
    # @param [String] handle Dictionary name.
    # @param [String] name Attribute name.
    # @return [void]
    def delete_attribute(ents, handle, name = nil)
      ents.each { |e|
        name ? e.delete_attribute(handle, name) : e.delete_attribute(handle)
      }
    end

    # Delete MSPhysics attributes from a collection of entities.
    # @param [Array<Sketchup::Entity>] ents A collection of entities.
    # @return [void]
    def delete_attributes(ents)
      ents.each { |e|
        e.delete_attribute('MSPhysics') if e.get_attribute('MSPhysics', 'Type', 'Body') == 'Body'
        e.delete_attribute('MSPhysics Body')
        #~ e.delete_attribute('MSPhysics Joint')
        dict = e.attribute_dictionary('MSPhysics Joint')
        if dict
          dict.keys.each { k|
            e.delete_attribute('MSPhysics Joint', k) if k != 'Type'
          }
        end
        e.delete_attribute('MSPhysics Script')
        e.delete_attribute('MSPhysics Buoyancy Plane')
      }
    end

    # Delete MSPhysics attributes from all entities.
    # @return [void]
    def delete_all_attributes
      model = Sketchup.active_model
      model.definitions.each { |definition|
        delete_attributes(definition.instances)
      }
      model.attribute_dictionaries.delete('MSPhysics')
      model.attribute_dictionaries.delete('MSPhysics Sounds')
      model.attribute_dictionaries.delete('MSPhysics Replay')
    end

    # Get entity type.
    # @param [Sketchup::Entity] e
    # @return [String, nil]
    def get_entity_type(e)
      type = e.get_attribute('MSPhysics', 'Type', nil)
      if type.nil? && (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance))
        type = 'Body'
      end
      type
    end

    # Set entity type.
    # @param [Sketchup::Entity] e
    # @param [String, nil] type
    # @return [String, nil] The new type.
    def set_entity_type(e, type)
      if e.is_a?(String)
        e.set_attribute('MSPhysics', 'Type', type)
        type
      else
        e.delete_attribute('MSPhysics', 'Type')
        nil
      end
    end

    # Get physical joint scale.
    # @return [Numeric]
    def get_joint_scale
      Sketchup.active_model.get_attribute('MSPhysics', 'Joint Scale', DEFAULT_JOINT_SCALE).to_f
    end

    # Set physical joint scale.
    # @param [Numeric] scale A value between 0.01 and 100.00
    # @return [Numeric]
    def set_joint_scale(scale)
      scale = AMS.clamp(scale.to_f, 0.01, 100.00)
      model = Sketchup.active_model
      op = 'MSPhysics - Scale Joints'
      Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
      model.set_attribute('MSPhysics', 'Joint Scale', scale)
      count = scale_joints(scale)
      model.commit_operation
      count
    end

    # Get version of the Newton Dynamics physics SDK.
    # @return [String]
    def get_newton_version
      MSPhysics::Newton.get_version
    end

    # Get float size of the Newton Dynamics physics SDK.
    # @return [Fixnum]
    def get_newton_float_size
      MSPhysics::Newton.get_float_size
    end

    # Get memory used by the Newton Dynamics physics SDK at the current time.
    # @return [Fixnum]
    def get_newton_memory_used
      MSPhysics::Newton.get_memory_used
    end

    # Create copy of a camera object.
    # @param [Sketchup::Camera] camera
    # @return [Sketchup::Camera]
    def duplicate_camera(camera)
      c = Sketchup::Camera.new(camera.eye, camera.target, camera.up)
      c.aspect_ratio = camera.aspect_ratio
      c.perspective = camera.perspective?
      if camera.perspective?
        c.focal_length = camera.focal_length
        c.fov = camera.fov
        c.image_width = camera.image_width
      else
        c.height = camera.height
      end
      c.description = camera.description
      return c
    end

    # Transition between two cameras.
    # @param [Sketchup::Camera] c1
    # @param [Sketchup::Camera] c2
    # @param [Numeric] ratio A value between 0.0 and 1.0
    # @return [Sketchup::Camera] Interpolated camera
    def transition_camera(c1, c2, ratio)
      ratio = AMS.clamp(ratio.to_f, 0.0, 1.0)
      t1 = Geom::Transformation.new(c1.xaxis, c1.direction, c1.up, c1.eye)
      t2 = Geom::Transformation.new(c2.xaxis, c2.direction, c2.up, c2.eye)
      t3 = Geom::Transformation.interpolate(t1, t2, ratio)
      c3 = Sketchup::Camera.new(t3.origin, t3.origin + t3.yaxis, t3.zaxis)
      c3.aspect_ratio = c1.aspect_ratio + (c2.aspect_ratio - c1.aspect_ratio) * ratio
      c3.perspective = c2.perspective?
      t = c1.perspective?
      if c3.perspective?
        c1.perspective = true
        c3.focal_length = c1.focal_length + (c2.focal_length - c1.focal_length) * ratio
        c3.fov = c1.fov + (c2.fov - c1.fov) * ratio
        c3.image_width = c1.image_width + (c2.image_width - c1.image_width) * ratio
      else
        c1.perspective = false
        c3.height = c1.height + (c2.height - c1.height) * ratio
      end
      c1.perspective = t
      c3.description = ratio == 0 ? c1.description : c2.description
      return c3
    end

    # Transition between two colors.
    # @param [Sketchup::Color] c1
    # @param [Sketchup::Color] c2
    # @param [Numeric] ratio A value between 0.0 and 1.0
    # @return [Sketchup::Color] Interpolated color
    def transition_color(c1, c2, ratio)
      ratio = AMS.clamp(ratio.to_f, 0.0, 1.0)
      return Sketchup::Color.new(
        (c1.red + (c2.red - c1.red) * ratio).to_i,
        (c1.green + (c2.green - c1.green) * ratio).to_i,
        (c1.blue + (c2.blue - c1.blue) * ratio).to_i,
        (c1.alpha + (c2.alpha - c1.alpha) * ratio).to_i)
    end

    # Transition between two points.
    # @param [Geom::Point3d] p1
    # @param [Geom::Point3d] p2
    # @param [Numeric] ratio A value between 0.0 and 1.0
    # @return [Geom::Point3d] Interpolated point
    def transition_point(p1, p2, ratio)
      ratio = AMS.clamp(ratio.to_f, 0.0, 1.0)
      return Geom::Point3d.new(
        p1.x + (p2.x - p1.x) * ratio,
        p1.y + (p2.y - p1.y) * ratio,
        p1.z + (p2.z - p1.z) * ratio)
    end

    # Transition between two vectors.
    # @param [Geom::Vector3d] v1
    # @param [Geom::Vector3d] v2
    # @param [Numeric] ratio A value between 0.0 and 1.0
    # @return [Geom::Vector3d] Interpolated vector
    def transition_vector(v1, v2, ratio)
      ratio = AMS.clamp(ratio.to_f, 0.0, 1.0)
      return v1.clone if (v1 == v2)
      if v1.length < EPSILON || v2.length < EPSILON || v1.samedirection?(v2)
        return Geom::Vector3d.new(
          v1.x + (v2.x - v1.x) * ratio,
          v1.y + (v2.y - v1.y) * ratio,
          v1.z + (v2.z - v1.z) * ratio)
      else
        v3 = v1.parallel?(v2) ? v1.axes[0] : v1.cross(v2)
        t = Geom::Transformation.new(ORIGIN, v3, v1)
        v2l = v2.transform(t.inverse)
        theta = Math.acos(v2l.y / v2l.length)
        theta = -theta if v2l.z < 0
        rtheta = theta * ratio
        rlength = v1.length + (v2.length - v1.length) * ratio
        v3l = Geom::Vector3d.new(0, Math.cos(rtheta) * rlength, Math.sin(rtheta) * rlength)
        return v3l.transform(t)
      end
    end

    # Transition between two transformation matrices.
    # @param [Geom::Transformation] t1
    # @param [Geom::Transformation] t2
    # @param [Numeric] ratio A value between 0.0 and 1.0
    # @return [Geom::Transformation] Interpolated transformation
    def transition_transformation(t1, t2, ratio)
      Geom::Transformation.interpolate(t1, t2, AMS.clamp(ratio.to_f, 0.0, 1.0))
    end

    # Transition between two numbers.
    # @param [Numeric] n1
    # @param [Numeric] n2
    # @param [Numeric] ratio A value between 0.0 and 1.0
    # @return [Numeric] Interpolated number
    def transition_number(n1, n2, ratio)
      n1 + (n2 - n1) * AMS.clamp(ratio.to_f, 0.0, 1.0)
    end

    # Get points on circle in 2D.
    # @param [Array<Numeric>] origin
    # @param [Numeric] radius
    # @param [Fixnum] num_seg Number of segments.
    # @param [Numeric] rot_angle Rotate angle in degrees.
    # @return [Array<Geom::Point3d>] An array of points on circle.
    def points_on_circle2d(origin, radius, num_seg = 16, rot_angle = 0)
      ra = rot_angle.degrees
      offset = Math::PI*2/num_seg.to_i
      pts = []
      for n in 0...num_seg.to_i
        angle = ra + (n*offset)
        pts << Geom::Point3d.new(Math.cos(angle)*radius + origin.x, Math.sin(angle)*radius + origin.y, 0)
      end
      pts
    end

    # Get points on circle in 3D.
    # @param [Array<Numeric>, Geom::Point3d] origin
    # @param [Array<Numeric>, Geom::Vector3d] normal
    # @param [Numeric] radius
    # @param [Fixnum] num_seg Number of segments.
    # @param [Numeric] rot_angle Rotate angle in degrees.
    # @return [Array<Geom::Point3d>] An array of points on circle.
    def points_on_circle3d(origin, radius, normal = Z_AXIS, num_seg = 16, rot_angle = 0)
      # Get the x and y axes
      origin = Geom::Point3d.new(origin) unless origin.is_a?(Geom::Point3d)
      normal = Geom::Vector3d.new(normal) unless normal.is_a?(Geom::Vector3d)
      xaxis = normal.axes[0]
      yaxis = normal.axes[1]
      xaxis.length = radius
      yaxis.length = radius
      # Compute points
      ra = rot_angle.degrees
      offset = Math::PI*2/num_seg.to_i
      pts = []
      for n in 0...num_seg.to_i
        angle = ra + (n*offset)
        vec = Geom.linear_combination(Math.cos(angle)*radius, xaxis, Math.sin(angle)*radius, yaxis)
        pts << origin + vec
      end
      pts
    end

    # Blend colors.
    # @param [Numeric] ratio between 0.0 and 1.0.
    # @param [Array<Sketchup::Color, String, Array>] colors An array of colors to blend.
    # @return [Sketchup::Color]
    def blend_colors(ratio, colors = ['white', 'black'])
      if colors.empty?
        raise(TypeError, 'Expected at least one color, but got none.', caller)
      end
      return Sketchup::Color.new(colors[0]) if colors.size == 1
      ratio = MSPhysics.clamp(ratio, 0, 1)
      cr = (colors.length-1)*ratio
      dec = cr-cr.to_i
      if dec == 0
        Sketchup::Color.new(colors[cr])
      else
        a = colors[cr.to_i].to_a
        b = colors[cr.ceil].to_a
        a[3] = 255 unless a[3]
        b[3] = 255 unless b[3]
        Sketchup::Color.new(((b[0]-a[0])*dec+a[0]).to_i, ((b[1]-a[1])*dec+a[1]).to_i, ((b[2]-a[2])*dec+a[2]).to_i, ((b[3]-a[3])*dec+a[3]).to_i)
      end
    end

    # Create a watermark text.
    # @param [Fixnum] x X position on screen.
    # @param [Fixnum] y Y position on screen.
    # @param [String] text Watermark text.
    # @param [String] name Watermark name.
    # @param [String] component Watermark component.
    # @return [Sketchup::Text, nil] A text object if successful.
    def add_watermark_text(x, y, text, name = 'watermark', component = 'version_text.skp')
      dir = File.dirname(__FILE__)
      dir.force_encoding("UTF-8") if RUBY_VERSION !~ /1.8/
      path = File.join(dir, "models/#{component}")
      return unless File.exists?(path)
      model = Sketchup.active_model
      view = model.active_view
      cd = model.definitions.load(path)
      ray = view.pickray(x,y)
      loc = ray[0]+ray[1]
      ci = model.entities.add_instance(cd, Geom::Transformation.new(loc))
      tt = ci.explode[0]
      tt.text = text
      tt.set_attribute('MSPhysics', 'name', name.to_s)
      mat = model.materials['MSPWatermarkText']
      unless mat
        mat = model.materials.add('MSPWatermarkText')
        mat.color = WATERMARK_COLOR
        tt.material = mat
      end
      layer = model.layers['MSPWatermarkText']
      unless layer
        layer = model.layers.add('MSPWatermarkText')
        layer.color = WATERMARK_COLOR if Sketchup.version.to_i > 13
      end
      tt.layer = layer
      tt
    end

    # Create a watermark text without material or layer.
    # @param [Fixnum] x X position on screen.
    # @param [Fixnum] y Y position on screen.
    # @param [String] text Watermark text.
    # @param [String] name Watermark name.
    # @param [String] component Watermark component.
    # @return [Sketchup::Text, nil] A text object if successful.
    def add_watermark_text2(x, y, text, name = 'watermark', component = 'version_text.skp')
      dir = File.dirname(__FILE__)
      dir.force_encoding("UTF-8") if RUBY_VERSION !~ /1.8/
      path = File.join(dir, "models/#{component}")
      return unless File.exists?(path)
      model = Sketchup.active_model
      view = model.active_view
      cd = model.definitions.load(path)
      ray = view.pickray(x,y)
      loc = ray[0]+ray[1]
      ci = model.entities.add_instance(cd, Geom::Transformation.new(loc))
      tt = ci.explode[0]
      tt.text = text
      tt.set_attribute('MSPhysics', 'name', name.to_s)
      tt
    end

    # Get watermark text by name.
    # @param [String] name
    # @return [Sketchup::Text, nil] A text object if the text exists.
    def get_watermark_text_by_name(name)
      Sketchup.active_model.entities.each { |e|
        return e if e.is_a?(Sketchup::Text) && e.get_attribute('MSPhysics', 'name') == name.to_s
      }
      nil
    end

    # Get all watermark texts.
    # @return [Array<Sketchup::Text>]
    def get_all_watermark_texts
      texts = []
      Sketchup.active_model.entities.each { |e|
        texts << e if e.is_a?(Sketchup::Text) && e.get_attribute('MSPhysics', 'name') != nil
      }
      texts
    end

    # Round number up to a particular decimal point.
    # @param [Numeric] number
    # @param [Fixnum] precision
    # @return [Numeric]
    def round(number, precision = 0)
      if RUBY_VERSION =~ /1.8/
        if precision.to_i == 0
          number.round
        else
          mag = 10**precision.to_i
          (number * mag).round / mag
        end
      else
        number.round(precision.to_i)
      end
    end

    private

    def scale_joints(scale, entities = Sketchup.active_model.entities)
      model = Sketchup.active_model
      st = Geom::Transformation.scaling(scale)
      count = 0
      entities.each { |e|
        next if !e.is_a?(Sketchup::Group) && !e.is_a?(Sketchup::ComponentInstance)
        if e.get_attribute('MSPhysics', 'Type', nil) == 'Joint'
          tra = e.transformation
          t = Geom::Transformation.new(tra.xaxis, tra.yaxis, tra.zaxis, tra.origin)
          e.transformation = t * st
          count += 1
        else
          ents = e.is_a?(Sketchup::ComponentInstance) ? e.definition.entities : e.entities
          count += scale_joints(scale, ents)
        end
      }
      count
    end

  end # class << self
end # module MSPhysics

unless file_loaded?(__FILE__)
  # Register Observers
  Sketchup.add_observer(MSPhysics::Dialog::AppObserver.new)
  Sketchup.add_observer(MSPhysics::Replay::AppObserver.new)
  # Setup audio
  if MSPhysics.sdl_used?
    sdl = MSPhysics::SDL
    mix = MSPhysics::Mixer
    sdl.init(sdl::INIT_AUDIO | sdl::INIT_JOYSTICK)
    mix.init(mix::INIT_SUPPORTED)
    mix.open_audio(22050, mix::DEFAULT_FORMAT, 2, 1024)
    mix.allocate_channels(16)
    Kernel.at_exit {
      MSPhysics::Music.destroy_all
      MSPhysics::Sound.destroy_all
      mix.close_audio
      mix.quit
      sdl.quit
    }
  end
  # Create cursors
  path = File.join(dir, 'images/cursors')
  MSPhysics::CURSORS.keys.each { |name|
    pt = MSPhysics::CURSOR_ORIGINS[name]
    MSPhysics::CURSORS[name] = UI.create_cursor(File.join(path, name.to_s + '.png'), pt[0], pt[1])
  }
  # Activate replay
  MSPhysics::Replay.load_replay_proc

  # Create some materials
  # Coefficients are defined from material to material contacts. Material to
  # another material coefficients are automatically calculated by averaging out
  # the coefficients of both.
  # [ name, density (kg/m^3), static friction, kinetic friction, elasticity, softness ]
  # Many coefficient values are estimated, averaged up, made up, and not accurate.
  mats = [
    ['Aluminium', 2700, 0.42, 0.34, 0.30, 0.01],
    ['Brass', 8730, 0.35, 0.24, 0.40, 0.01],
    ['Brick', 1920, 0.60, 0.55, 0.20, 0.01],
    ['Bronze', 8200, 0.36, 0.27, 0.60, 0.01],
    ['Cadnium', 8640, 0.79, 0.46, 0.60, 0.01],
    ['Cast Iron', 7300, 0.51, 0.40, 0.60, 0.01],
    ['Chromium', 7190, 0.46, 0.30, 0.60, 0.01],
    ['Cobalt', 8746, 0.56, 0.40, 0.60, 0.01],
    ['Concrete', 2400, 0.62, 0.56, 0.20, 0.01],
    ['Glass', 2800, 0.90, 0.72, 0.4, 0.01],
    ['Copper', 8940, 0.55, 0.40, 0.60, 0.01],
    ['Gold', 19320, 0.49, 0.39, 0.60, 0.01],
    ['Graphite', 2230, 0.18, 0.14, 0.10, 0.01],
    ['Ice', 916, 0.01, 0.01, 0.10, 0.01],
    ['Nickel', 8900, 0.53, 0.44, 0.60, 0.01],
    ['Plastic', 1000, 0.35, 0.30, 0.69, 0.01],
    ['Rubber', 1100, 1.16, 1.16, 0.01, 0.01],
    ['Silver', 10500, 0.50, 0.40, 0.60, 0.01],
    ['Steel', 8050, 0.31, 0.23, 0.60, 0.01],
    ['Teflon', 2170, 0.04, 0.03, 0.10, 0.01],
    ['Titanium', 4500, 0.36, 0.30, 0.40, 0.01],
    ['Tungsten Carbide', 19600, 0.22, 0.15, 0.40, 0.01],
    ['Wood', 700, 0.50, 0.25, 0.40, 0.01],
    ['Zinc', 7000, 0.60, 0.50, 0.60, 0.01]
  ]
  mats.each { |args|
    mat = MSPhysics::Material.new(*args)
    MSPhysics::Materials.add(mat)
  }

  use_orig = Sketchup.read_default('MSPhysics', 'Use Original Icons', false) ? true : false
  if Sketchup.version.to_i > 13 && !use_orig
    simg_path = 'images/icons/'
    limg_path = 'images/icons/'
  else
    simg_path = 'images/small/'
    limg_path = 'images/large/'
  end

  # Create MSPhysics Simulation Toolbar
  sim = MSPhysics::Simulation
  sim_toolbar = UI::Toolbar.new 'MSPhysics'

  cmd = UI::Command.new('Toggle UI'){
    MSPhysics::Dialog.show( !MSPhysics::Dialog.is_visible? )
  }
  cmd.set_validation_proc {
    MSPhysics::Dialog.is_visible? ? MF_CHECKED : MF_UNCHECKED
  }
  cmd.menu_text = cmd.tooltip = 'Toggle UI'
  cmd.status_bar_text = 'Show/Hide MSPhysics UI.'
  cmd.small_icon = simg_path + 'ui.png'
  cmd.large_icon = limg_path + 'ui.png'
  sim_toolbar.add_item(cmd)

  cmd = UI::Command.new('Toggle Play'){
    sim.is_active? ? sim.instance.toggle_play : sim.start
  }
  cmd.set_validation_proc {
    if sim.is_active?
      sim.instance.is_playing? ? MF_CHECKED : MF_UNCHECKED
    else
      MF_ENABLED
    end
  }
  cmd.menu_text = cmd.tooltip = 'Toggle Play'
  cmd.status_bar_text = 'Play/Pause simulation.'
  cmd.small_icon = simg_path + 'toggle_play.png'
  cmd.large_icon = limg_path + 'toggle_play.png'
  sim_toolbar.add_item(cmd)

  cmd = UI::Command.new('Reset'){
    sim.reset
  }
  cmd.set_validation_proc {
    sim.is_active? ? MF_ENABLED : MF_GRAYED
  }
  cmd.menu_text = cmd.tooltip = 'Reset'
  cmd.status_bar_text = 'Reset simulation.'
  cmd.small_icon = simg_path + 'reset.png'
  cmd.large_icon = limg_path + 'reset.png'
  sim_toolbar.add_item(cmd)

  sim_toolbar.show


  # Create MSPhysics Joints Toolbar
  joints_toolbar = UI::Toolbar.new 'MSPhysics Joints'

  cmd = UI::Command.new('cmd'){
    tool = MSPhysics::JointConnectionTool
    tool.is_active? ? tool.deactivate : tool.activate
  }
  cmd.menu_text = cmd.tooltip = 'Joint Connection Tool'
  cmd.status_bar_text = 'Activate/Deactivate joint connection tool.'
  cmd.set_validation_proc {
    MSPhysics::JointConnectionTool.is_active? ? MF_CHECKED : MF_UNCHECKED
  }
  cmd.small_icon = simg_path + 'toggle_connect.png'
  cmd.large_icon = limg_path + 'toggle_connect.png'
  joints_toolbar.add_item(cmd)

  cmd = UI::Command.new('Scale MSPhysics Joints'){
    scale = MSPhysics.get_joint_scale
    prompts = ['Scale']
    defaults = [sprintf("%0.2f", scale)]
    list = ['0.05|0.10|0.25|0.50|0.75|1.00|1.25|1.50|1.75|2.00|3.00|4.00|5.00|10.00']
    input = UI.inputbox(prompts, defaults, list, 'Scale MSPhysics Joints')
    next unless input
    scale = input[0].to_f
    count = MSPhysics.set_joint_scale(scale)
    UI.messagebox("Edited scale of #{count} MSPhysics joint(s).")
  }
  cmd.menu_text = cmd.tooltip = 'Edit Joints Scale'
  cmd.status_bar_text = 'Change scale of MSPhysics joints.'
  cmd.small_icon = simg_path + 'scale_joints.png'
  cmd.large_icon = limg_path + 'scale_joints.png'
  joints_toolbar.add_item(cmd)

  joints_toolbar.add_separator

  MSPhysics::JOINT_TYPES.values.sort.each { |value|
    type = RUBY_VERSION =~ /1.8/ ? MSPhysics::JOINT_TYPES.index(value) : MSPhysics::JOINT_TYPES.key(value)
    name = type.to_s
    words = name.split('_')
    for i in 0...words.size
      words[i].capitalize!
    end
    ename = words.join(' ')
    jt = nil
    cmd = UI::Command.new('cmd') {
      jt = MSPhysics::JointTool.new(type)
    }
    cmd.set_validation_proc {
      jt != nil && jt.is_active? ? MF_CHECKED : MF_UNCHECKED
    }
    cmd.menu_text = cmd.tooltip = ename
    cmd.status_bar_text = "Add #{ename} joint."
    cmd.small_icon = simg_path + name + '.png'
    cmd.large_icon = limg_path + name + '.png'
    joints_toolbar.add_item(cmd)
  }

  joints_toolbar.show


  # Create Replay Toolbar
  replay_toolbar = UI::Toolbar.new 'MSPhysics Replay'

  cmd = UI::Command.new('Toggle Record'){
    MSPhysics::Replay.record_enabled = !MSPhysics::Replay.record_enabled?
  }
  cmd.set_validation_proc {
    MSPhysics::Replay.record_enabled? ? MF_CHECKED : MF_UNCHECKED
  }
  cmd.menu_text = cmd.tooltip = 'Toggle Record'
  cmd.status_bar_text = 'Enable/disable replay animation recording.'
  cmd.small_icon = simg_path + 'replay_record.png'
  cmd.large_icon = limg_path + 'replay_record.png'
  replay_toolbar.add_item(cmd)

  cmd = UI::Command.new('Toggle Camera Replay'){
    MSPhysics::Replay.camera_replay_enabled = !MSPhysics::Replay.camera_replay_enabled?
  }
  cmd.set_validation_proc {
    MSPhysics::Replay.camera_replay_enabled? ? MF_CHECKED : MF_UNCHECKED
  }
  cmd.menu_text = cmd.tooltip = 'Toggle Camera Replay'
  cmd.status_bar_text = 'Enable/disable camera replay.'
  cmd.small_icon = simg_path + 'replay_camera.png'
  cmd.large_icon = limg_path + 'replay_camera.png'
  replay_toolbar.add_item(cmd)

  cmd = UI::Command.new('Play'){
    if MSPhysics::Replay.active?
      if MSPhysics::Replay.paused? || MSPhysics::Replay.reversed?
        MSPhysics::Replay.reversed = false
        MSPhysics::Replay.play
      else
        MSPhysics::Replay.pause
      end
    else
      MSPhysics::Replay.reversed = false
      MSPhysics::Replay.start
      MSPhysics::Replay.play
    end
  }
  cmd.set_validation_proc {
    next MF_GRAYED unless MSPhysics::Replay.active_data_valid?
    if MSPhysics::Replay.active?
      MSPhysics::Replay.playing? && !MSPhysics::Replay.reversed? ? MF_CHECKED : MF_UNCHECKED
    else
      MF_ENABLED
    end
  }
  cmd.menu_text = cmd.tooltip = 'Play'
  cmd.status_bar_text = 'Play replay animation forward.'
  cmd.small_icon = simg_path + 'replay_play.png'
  cmd.large_icon = limg_path + 'replay_play.png'
  replay_toolbar.add_item(cmd)

  cmd = UI::Command.new('Reverse'){
    if MSPhysics::Replay.active?
      if MSPhysics::Replay.paused? || !MSPhysics::Replay.reversed?
        MSPhysics::Replay.reversed = true
        MSPhysics::Replay.play
      else
        MSPhysics::Replay.pause
      end
    else
      MSPhysics::Replay.reversed = true
      MSPhysics::Replay.start
      MSPhysics::Replay.play
    end
  }
  cmd.set_validation_proc {
    next MF_GRAYED unless MSPhysics::Replay.active_data_valid?
    if MSPhysics::Replay.active?
      MSPhysics::Replay.playing? && MSPhysics::Replay.reversed? ? MF_CHECKED : MF_UNCHECKED
    else
      MF_ENABLED
    end
  }
  cmd.menu_text = cmd.tooltip = 'Reverse'
  cmd.status_bar_text = 'Play replay animation backward.'
  cmd.small_icon = simg_path + 'replay_reverse.png'
  cmd.large_icon = limg_path + 'replay_reverse.png'
  replay_toolbar.add_item(cmd)

  cmd = UI::Command.new('Pause'){
    if MSPhysics::Replay.paused?
      MSPhysics::Replay.play
    else
      MSPhysics::Replay.pause
    end
  }
  cmd.set_validation_proc {
    next MF_GRAYED unless MSPhysics::Replay.active_data_valid?
    if MSPhysics::Replay.active?
      MSPhysics::Replay.paused? ? MF_CHECKED : MF_UNCHECKED
    else
      MF_GRAYED
    end
  }
  cmd.menu_text = cmd.tooltip = 'Pause'
  cmd.status_bar_text = 'Pause replay animation.'
  cmd.small_icon = simg_path + 'replay_pause.png'
  cmd.large_icon = limg_path + 'replay_pause.png'
  replay_toolbar.add_item(cmd)

  cmd = UI::Command.new('Reset'){
    MSPhysics::Replay.reset
  }
  cmd.set_validation_proc {
    MSPhysics::Replay.active? ? MF_ENABLED : MF_GRAYED
  }
  cmd.menu_text = cmd.tooltip = 'Reset'
  cmd.status_bar_text = 'Stop replay animation and reset positions.'
  cmd.small_icon = simg_path + 'replay_reset.png'
  cmd.large_icon = limg_path + 'replay_reset.png'
  replay_toolbar.add_item(cmd)

  cmd = UI::Command.new('Stop'){
    MSPhysics::Replay.stop
  }
  cmd.set_validation_proc {
    MSPhysics::Replay.active? ? MF_ENABLED : MF_GRAYED
  }
  cmd.menu_text = cmd.tooltip = 'Stop'
  cmd.status_bar_text = 'Stop replay animation, but avoid resetting positions.'
  cmd.small_icon = simg_path + 'replay_stop.png'
  cmd.large_icon = limg_path + 'replay_stop.png'
  replay_toolbar.add_item(cmd)

  inc_spd_cmd = UI::Command.new('Increase Speed'){
    v = MSPhysics::Replay.speed
    MSPhysics::Replay.speed = v + (v < 10.0 ? (v < 2.0 ? (v < 0.1 ? 0.01 : 0.1) : 1.0) : 10.0)
  }
  inc_spd_cmd.set_validation_proc {
    inc_spd_cmd.status_bar_text = "Increase replay animation speed.    Speed: #{sprintf("%.2f", MSPhysics::Replay.speed)}"
    MF_ENABLED
  }
  inc_spd_cmd.menu_text = inc_spd_cmd.tooltip = 'Increase Speed'
  inc_spd_cmd.status_bar_text = "Increase replay animation speed.    Speed: #{sprintf("%.2f", MSPhysics::Replay.speed)}"
  inc_spd_cmd.small_icon = simg_path + 'replay_increase_speed.png'
  inc_spd_cmd.large_icon = limg_path + 'replay_increase_speed.png'
  replay_toolbar.add_item(inc_spd_cmd)

  dec_spd_cmd = UI::Command.new('Decrease Speed'){
    v = MSPhysics::Replay.speed
    MSPhysics::Replay.speed = v - (v > 10.0 ? 10.0 : (v > 2.0 ? 1.0 : (v > 0.1 ? 0.1 : 0.01)))
  }
  dec_spd_cmd.set_validation_proc {
    dec_spd_cmd.status_bar_text = "Decrease replay animation speed.    Speed: #{sprintf("%.2f", MSPhysics::Replay.speed)}"
    MF_ENABLED
  }
  dec_spd_cmd.menu_text = dec_spd_cmd.tooltip = 'Decrease Speed'
  dec_spd_cmd.status_bar_text = "Decrease replay animation speed.    Speed: #{sprintf("%.2f", MSPhysics::Replay.speed)}"
  dec_spd_cmd.small_icon = simg_path + 'replay_decrease_speed.png'
  dec_spd_cmd.large_icon = limg_path + 'replay_decrease_speed.png'
  replay_toolbar.add_item(dec_spd_cmd)

  cmd = UI::Command.new('Clear Data') {
    MSPhysics::Replay.clear_active_data
    MSPhysics::Replay.clear_data_from_model(!MSPhysics::Simulation.is_active?)
  }
  cmd.set_validation_proc {
    MSPhysics::Replay.active_data_valid? && !MSPhysics::Replay.active? ? MF_ENABLED : MF_GRAYED
  }
  cmd.menu_text = cmd.tooltip = 'Clear Data'
  cmd.status_bar_text = 'Clear recorded data.'
  cmd.small_icon = simg_path + 'replay_destroy.png'
  cmd.large_icon = limg_path + 'replay_destroy.png'
  replay_toolbar.add_item(cmd)

  replay_toolbar.show


  # Create Edit Menus
  UI.add_context_menu_handler { |menu|
    model = Sketchup.active_model
    bodies = []
    joints = []
    buoyancy_planes = []
    curves = []
    model.selection.each { |e|
      if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        case e.get_attribute('MSPhysics', 'Type', 'Body')
        when 'Body'
          bodies << e
        when 'Joint'
          joints << e
        when 'Buoyancy Plane'
          buoyancy_planes << e
        end
      elsif e.is_a?(Sketchup::Edge) && e.curve != nil && !curves.include?(e.curve)
        curves << e.curve
      end
    }
    next if bodies.empty? && joints.empty? && buoyancy_planes.empty? && curves.size != 1
    msp_menu = menu.add_submenu('MSPhysics')
    if bodies.size > 0
      if joints.empty? && buoyancy_planes.empty? && curves.empty?
        body_menu = msp_menu
      else
        text = bodies.size > 1 ? "#{bodies.size} Bodies" : "Body"
        body_menu = msp_menu.add_submenu(text)
      end
      state_menu = body_menu.add_submenu('State')
      state_opts = ['Ignore']
      con_state_opts = ['Clear Ignore Flag']
      if model.active_entities == model.entities
        state_opts.concat ['Static', 'Frozen', 'Magnetic', 'Collidable', 'Auto Sleep', 'Continuous Collision', 'Enable Friction', 'Enable Script', 'Enable Gravity', 'Enable Thruster', 'Enable Emitter', 'Connect Closest Joints']
        con_state_opts.concat ['Movable', 'Non-Frozen', 'Non-Magnetic', 'Non-Collidable', 'No Auto Sleep', 'No Continuous Collision', 'Disable Friction', 'Disable Script', 'Disable Gravity', 'Disable Thruster', 'Disable Emitter', 'Connect All Joints']

        shape_menu = body_menu.add_submenu('Shape')
        default_shape = MSPhysics::DEFAULT_BODY_SETTINGS[:shape]
        ['Box', 'Sphere', 'Cone', 'Cylinder', 'Chamfer Cylinder', 'Capsule', 'Convex Hull', 'Null', 'Compound', 'Compound from CD', 'Static Mesh'].each { |shape|
          item = shape_menu.add_item(shape){
            op = 'MSPhysics Body - Change Shape'
            Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
            MSPhysics.set_attribute(bodies, 'MSPhysics Body', 'Shape', shape)
            model.commit_operation
            MSPhysics::Dialog.update_body_state
          }
          shape_menu.set_validation_proc(item){
            MSPhysics.get_attribute(bodies, 'MSPhysics Body', 'Shape', default_shape) == shape ? MF_CHECKED : MF_UNCHECKED
          }
        }

        mat_menu = body_menu.add_submenu('Material')
        default_mat = MSPhysics::DEFAULT_BODY_SETTINGS[:material_name]
        item = mat_menu.add_item(default_mat){
          op = 'MSPhysics Body - Change Material'
          Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
          ['Material', 'Density', 'Static Friction', 'Dynamic Friction', 'Enable Friction', 'Elasticity', 'Softness'].each { |option|
            MSPhysics.delete_attribute(bodies, 'MSPhysics Body', option)
          }
          model.commit_operation
          MSPhysics::Dialog.update_body_state
        }
        mat_menu.set_validation_proc(item){
          MSPhysics.get_attribute(bodies, 'MSPhysics Body', 'Material', default_mat) == default_mat ? MF_CHECKED : MF_UNCHECKED
        }
        item = mat_menu.add_item('Custom'){
          op = 'MSPhysics Body - Change Material'
          Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
          MSPhysics.set_attribute(bodies, 'MSPhysics Body', 'Material', 'Custom')
          model.commit_operation
          MSPhysics::Dialog.update_body_state
        }
        mat_menu.set_validation_proc(item){
          MSPhysics.get_attribute(bodies, 'MSPhysics Body', 'Material', default_mat) == 'Custom' ? MF_CHECKED : MF_UNCHECKED
        }
        mat_menu.add_separator
        materials = MSPhysics::Materials.sort { |a, b| a.get_name <=> b.get_name }
        materials.each { |material|
          item = mat_menu.add_item(material.get_name){
            op = 'MSPhysics Body - Change Material'
            Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
            MSPhysics.set_attribute(bodies, 'MSPhysics Body', 'Material', material.get_name)
            MSPhysics.set_attribute(bodies, 'MSPhysics Body', 'Density', material.get_density)
            MSPhysics.set_attribute(bodies, 'MSPhysics Body', 'Static Friction', material.get_static_friction)
            MSPhysics.set_attribute(bodies, 'MSPhysics Body', 'Dynamic Friction', material.get_dynamic_friction)
            MSPhysics.set_attribute(bodies, 'MSPhysics Body', 'Enable Friction', true)
            MSPhysics.set_attribute(bodies, 'MSPhysics Body', 'Elasticity', material.get_elasticity)
            MSPhysics.set_attribute(bodies, 'MSPhysics Body', 'Softness', material.get_softness)
            model.commit_operation
            MSPhysics::Dialog.update_body_state
          }
          mat_menu.set_validation_proc(item){
            MSPhysics.get_attribute(bodies, 'MSPhysics Body', 'Material', default_mat) == material.get_name ? MF_CHECKED : MF_UNCHECKED
          }
        }
      end
      if (bodies.size == 1)
        state_opts.each { |option|
          default_state = MSPhysics::DEFAULT_BODY_SETTINGS[option.downcase.gsub(' ', '_').to_sym]
          item = state_menu.add_item(option) {
            op = 'MSPhysics Body - Change State'
            Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
            state = MSPhysics.get_attribute(bodies, 'MSPhysics Body', option, default_state) ? true : false
            MSPhysics.set_attribute(bodies, 'MSPhysics Body', option, !state)
            model.commit_operation
            MSPhysics::Dialog.update_body_state
          }
          state_menu.set_validation_proc(item) {
            MSPhysics.get_attribute(bodies, 'MSPhysics Body', option, default_state) ? MF_CHECKED : MF_UNCHECKED
          }
        }
      else
        (0...state_opts.length).each { |i|
          option = state_opts[i]
          con_option = con_state_opts[i]
          state_menu.add_item(option) {
            op = 'MSPhysics Body - Change State'
            Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
            MSPhysics.set_attribute(bodies, 'MSPhysics Body', option, true)
            model.commit_operation
            MSPhysics::Dialog.update_body_state
          }
          state_menu.add_item(con_option) {
            op = 'MSPhysics Body - Change State'
            Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
            MSPhysics.set_attribute(bodies, 'MSPhysics Body', option, false)
            model.commit_operation
            MSPhysics::Dialog.update_body_state
          }
        }
      end
      body_menu.add_item('Clear Connected Joints') {
        op = 'MSPhysics Body - Clear Connected Joints'
        Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
        MSPhysics.delete_attribute(bodies, 'MSPhysics Body', 'Connected Joints')
        model.commit_operation
      }
      body_menu.add_item('Reset Properties') {
        op = 'MSPhysics Body - Reset Properties'
        Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
        MSPhysics.delete_attribute(bodies, 'MSPhysics')
        bodies.each { |e|
          dict = e.attribute_dictionary('MSPhysics Body')
          if dict
            dict.keys.each { |k|
              next if k == 'Connect Closest Joints' || k == 'Connected Joints'
              e.delete_attribute('MSPhysics Body', k)
            }
          end
        }
        model.commit_operation
      }
      body_menu.add_item('Clear Script') {
        op = 'MSPhysics Body - Clear Script'
        Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
        MSPhysics.delete_attribute(bodies, 'MSPhysics Script')
        model.commit_operation
      }
    end
    if joints.size > 0
      if bodies.empty? && buoyancy_planes.empty? && curves.empty?
        joint_menu = msp_menu
      else
        text = joints.size > 1 ? "#{joints.size} Joints" : "Joint"
        joint_menu = msp_menu.add_submenu(text)
      end
      joint_menu.add_item('Make Unique ID') {
        op = 'MSPhysics Joint - Make Unique ID'
        Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
        MSPhysics.delete_attribute(joints, 'MSPhysics Joint', 'ID')
        joints.each { |joint|
          id = MSPhysics::JointTool.generate_uniq_id
          joint.set_attribute('MSPhysics Joint', 'ID', id)
        }
        model.commit_operation
      }
      if joints.size > 1
        joint_menu.add_item('Make Same ID') {
          op = 'MSPhysics Joint - Make Same ID'
          Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
          id = MSPhysics::JointTool.generate_uniq_id
          MSPhysics.set_attribute(joints, 'MSPhysics Joint', 'ID', id)
          model.commit_operation
        }
      end
      joint_type_menu = joint_menu.add_submenu('Type')
      %w(Standard Flexible Robust).each { |jname|
        jtype = jname == 'Robust' ? 2 : (jname == 'Flexible' ? 1 : 0)
        item = joint_type_menu.add_item(jname) {
          op = 'MSPhysics Joint - Type'
          Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
          MSPhysics.set_attribute(joints, 'MSPhysics Joint', 'Constraint Type', jtype)
          model.commit_operation
        }
        joint_type_menu.set_validation_proc(item) {
          MSPhysics.get_attribute(joints, 'MSPhysics Joint', 'Constraint Type', MSPhysics::Joint::DEFAULT_CONSTRAINT_TYPE) == jtype ? MF_CHECKED : MF_UNCHECKED
        }
      }
      item = joint_menu.add_item('Connected Collide') {
        op = 'MSPhysics Joint - Make Same ID'
        Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
        state = MSPhysics.get_attribute(joints, 'MSPhysics Joint', 'Bodies Collidable', MSPhysics::Joint::DEFAULT_BODIES_COLLIDABLE) ? true : false
        MSPhysics.set_attribute(joints, 'MSPhysics Joint', 'Bodies Collidable', !state)
        model.commit_operation
      }
      joint_type_menu.set_validation_proc(item) {
        MSPhysics.get_attribute(joints, 'MSPhysics Joint', 'Bodies Collidable', MSPhysics::Joint::DEFAULT_CONSTRAINT_TYPE) ? MF_CHECKED : MF_UNCHECKED
      }
      joint_menu.add_item('Reset Properties') {
        op = 'MSPhysics Joint - Reset Properties'
        Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
        #~ MSPhysics.delete_attribute(joints, 'MSPhysics Joint')
        joints.each { |joint|
          joint.attribute_dictionary('MSPhysics Joint').keys.each { k|
            joint.delete_attribute('MSPhysics Joint', k) if k != 'Type'
          }
        }
        model.commit_operation
      }
    end
    if buoyancy_planes.size > 0
      if bodies.empty? && joints.empty? && curves.empty?
        bp_menu = msp_menu
      else
        text = buoyancy_planes.size > 1 ? "#{buoyancy_planes.size} Buoyancy Planes" : "Buoyancy Plane"
        bp_menu = msp_menu.add_submenu(text)
      end
      bp_menu.add_item("Properties"){
        default = MSPhysics::DEFAULT_BUOYANCY_PLANE_SETTINGS
        prompts = ['Density (kg/m³)', 'Viscosity (0.0 - 1.0)', 'Current X', 'Current Y', 'Current Z']
        dict = 'MSPhysics Buoyancy Plane'
        ddensity = MSPhysics.get_attribute(buoyancy_planes, dict, 'Density', default[:density])
        dviscosity = MSPhysics.get_attribute(buoyancy_planes, dict, 'Viscosity', default[:viscosity])
        dcurrent_x = MSPhysics.get_attribute(buoyancy_planes, dict, 'Current X', default[:current_x])
        dcurrent_y = MSPhysics.get_attribute(buoyancy_planes, dict, 'Current Y', default[:current_y])
        dcurrent_z = MSPhysics.get_attribute(buoyancy_planes, dict, 'Current Z', default[:current_z])
        defaults = [ddensity, dviscosity, dcurrent_x, dcurrent_y, dcurrent_z]
        input = UI.inputbox(prompts, defaults, 'Buoyancy Plane Properties')
        next unless input
        density = AMS.clamp(input[0].to_f, 0.001, nil)
        viscosity = AMS.clamp(input[1].to_f, 0, 1)
        current_x = input[2].to_f
        current_y = input[3].to_f
        current_z = input[4].to_f
        op = 'MSPhysics Buoyancy - Edit Plane Properties'
        Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
        MSPhysics.set_attribute(buoyancy_planes, dict, 'Density', density)
        MSPhysics.set_attribute(buoyancy_planes, dict, 'Viscosity', viscosity)
        MSPhysics.set_attribute(buoyancy_planes, dict, 'Current X', current_x)
        MSPhysics.set_attribute(buoyancy_planes, dict, 'Current Y', current_y)
        MSPhysics.set_attribute(buoyancy_planes, dict, 'Current Z', current_z)
        model.commit_operation
      }
    end
    if curves.size == 1
      curve_name = curves[0].get_attribute('MSPhysics Curve', 'Name')
      text = curve_name.is_a?(String) ? "Curve: #{curve_name}" : "Curve"
      c_menu = msp_menu.add_submenu(text)
      c_menu.add_item("Name Curve") {
        promts = ['Name']
        defaults = [curve_name.to_s]
        input = UI.inputbox(promts, defaults, 'Curve Name')
        next unless input
        if input[0].empty?
          curves[0].delete_attribute('MSPhysics Curve')
        else
          curves[0].set_attribute('MSPhysics Curve', 'Name', input[0])
        end
      }
      c_menu.add_item("Unname Curve") {
        curves[0].delete_attribute('MSPhysics Curve')
      }
    end
  }

  # Create Plugin Menus
  plugin_menu = UI.menu('Plugins').add_submenu('MSPhysics')

  item = plugin_menu.add_item('Export Replay to Images') {
    MSPhysics::Replay.export_to_images
  }
  plugin_menu.set_validation_proc(item) {
    MSPhysics::Replay.active_data_valid? ? MF_ENABLED : MF_GRAYED
  }

  item = plugin_menu.add_item('Export Replay to SKP') {
    MSPhysics::Replay.export_to_skp
  }
  plugin_menu.set_validation_proc(item) {
    MSPhysics::Replay.active_data_valid? ? MF_ENABLED : MF_GRAYED
  }

  item = plugin_menu.add_item('Export Replay to Kerkythea') {
    MSPhysics::Replay.export_to_kerkythea
  }
  plugin_menu.set_validation_proc(item) {
    MSPhysics::Replay.active_data_valid? ? MF_ENABLED : MF_GRAYED
  }

  item = plugin_menu.add_item('Export Replay to SkIndigo') {
    MSPhysics::Replay.export_to_skindigo
  }
  plugin_menu.set_validation_proc(item) {
    MSPhysics::Replay.active_data_valid? ? MF_ENABLED : MF_GRAYED
  }

  item = plugin_menu.add_item('Replay Settings') {
    prompts = ['Replay Materials', 'Replay Layers', 'Replay Camera', 'Replay Render', 'Replay Shadow']
    defaults = [
      MSPhysics::Replay.materials_replay_enabled? ? 'Yes' : 'No',
      MSPhysics::Replay.layers_replay_enabled? ? 'Yes' : 'No',
      MSPhysics::Replay.camera_replay_enabled? ? 'Yes' : 'No',
      MSPhysics::Replay.render_replay_enabled? ? 'Yes' : 'No',
      MSPhysics::Replay.shadow_replay_enabled? ? 'Yes' : 'No'
    ]
    yn = 'Yes|No'
    drop_downs = [yn, yn, yn, yn, yn]
    input = UI.inputbox(prompts, defaults, drop_downs, 'Replay Settings')
    next unless input
    MSPhysics::Replay.materials_replay_enabled = input[0] == 'Yes'
    MSPhysics::Replay.layers_replay_enabled = input[1] == 'Yes'
    MSPhysics::Replay.camera_replay_enabled = input[2] == 'Yes'
    MSPhysics::Replay.render_replay_enabled = input[3] == 'Yes'
    MSPhysics::Replay.shadow_replay_enabled = input[4] == 'Yes'
    model = Sketchup.active_model
    op = 'MSPhysics Replay - Save Settings'
    Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
    MSPhysics::Replay.save_replay_settings
    model.commit_operation
  }

  plugin_menu.add_separator

  plugin_menu.add_item('Create Buoyancy Plane'){
    default = MSPhysics::DEFAULT_BUOYANCY_PLANE_SETTINGS
    prompts = ['Density (kg/m³)', 'Viscosity (0.0 - 1.0)', 'Current X', 'Current Y', 'Current Z']
    defaults = [default[:density], default[:viscosity], default[:current_x], default[:current_y], default[:current_z]]
    input = UI.inputbox(prompts, defaults, 'Buoyancy Plane Properties')
    next unless input
    density = AMS.clamp(input[0].to_f, 0.001, nil)
    viscosity = AMS.clamp(input[1].to_f, 0, 1)
    current_x = input[2].to_f
    current_y = input[3].to_f
    current_z = input[4].to_f
    model = Sketchup.active_model
    op = 'MSPhysics Buoyancy - Create Plane'
    Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
    mat = model.materials[default[:material_name]]
    unless mat
      mat = model.materials.add(default[:material_name])
      mat.color = default[:color]
      mat.alpha = default[:alpha]
    end
    group = model.entities.add_group
    s = default[:plane_size] * 0.5
    group.entities.add_face([-s, -s, 0], [s, -s, 0], [s, s, 0], [-s, s, 0])
    group.material = mat
    dict = 'MSPhysics Buoyancy Plane'
    group.set_attribute('MSPhysics', 'Type', 'Buoyancy Plane')
    group.set_attribute(dict, 'Density', density)
    group.set_attribute(dict, 'Viscosity', viscosity)
    group.set_attribute(dict, 'Current X', current_x)
    group.set_attribute(dict, 'Current Y', current_y)
    group.set_attribute(dict, 'Current Z', current_z)
    model.commit_operation
  }

  plugin_menu.add_separator

  plugin_menu.add_item('Select All Joints') {
    model = Sketchup.active_model
    model.selection.clear
    model.definitions.each { |d|
      d.instances.each { |i|
        model.selection.add(i) if i.get_attribute('MSPhysics', 'Type') == 'Joint'
      }
    }
  }
  plugin_menu.add_item('Delete All Attributes'){
    msg = "This option removes all MSPhysics assigned properties, scripts, and record of connected joints.\n"
    msg << "Do you want to proceed?"
    choice = UI.messagebox(msg, MB_YESNO)
    if choice == IDYES
      model = Sketchup.active_model
      op = 'MSPhysics - Delete All Attributes'
      Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
      MSPhysics.delete_all_attributes
      model.commit_operation
    end
  }

  plugin_menu.add_item('Purge Unused'){
    model = Sketchup.active_model
    op = 'MSPhysics - Purge Unused'
    Sketchup.version.to_i > 6 ? model.start_operation(op, true) : model.start_operation(op)
    model.definitions.purge_unused
    model.materials.purge_unused
    model.layers.purge_unused
    model.styles.purge_unused
    model.commit_operation
  }

  if Sketchup.version.to_i > 13
    item = plugin_menu.add_item('Use Original Icons') {
      use_orig = Sketchup.read_default('MSPhysics', 'Use Original Icons', false) ? true : false
      Sketchup.write_default('MSPhysics', 'Use Original Icons', !use_orig)
      UI.messagebox('The change will take place when SketchUp is re-launched.', MB_OK)
    }
    plugin_menu.set_validation_proc(item) {
      Sketchup.read_default('MSPhysics', 'Use Original Icons', false) ? MF_CHECKED : MF_UNCHECKED
    }
  end

  plugin_menu.add_item('About'){
    msg = "MSPhysics #{MSPhysics::VERSION} -- #{MSPhysics::RELEASE_DATE}\n"
    msg << "Powered by the Newton Dynamics #{MSPhysics::Newton.get_version} physics SDK by Julio Jerez.\n"
    msg << "Copyright MIT © 2015-2016, Anton Synytsia.\n"
    msg << "Credits to\n"
    msg << "- Chris Phillips for ideas from SketchyPhysics.\n"
    msg << "- István Nagy (PituPhysics) for examples and testing.\n"
    UI.messagebox(msg)
  }

  file_loaded(__FILE__)
end
