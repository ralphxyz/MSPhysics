#ifndef MSP_SLIDER_H
#define MSP_SLIDER_H

#include "msp_util.h"
#include "msp_joint.h"

namespace MSNewton {
	class Slider;
}

class MSNewton::Slider {
private:
	// Variables
	static const dFloat DEFAULT_MIN;
	static const dFloat DEFAULT_MAX;
	static const bool DEFAULT_LIMITS_ENABLED;
	static const dFloat DEFAULT_FRICTION;
	static const dFloat DEFAULT_CONTROLLER;

public:
	// Structures
	typedef struct SliderData
	{
		dFloat cur_pos;
		dFloat cur_vel;
		dFloat cur_accel;
		dFloat min;
		dFloat max;
		bool limits_enabled;
		dFloat friction;
		dFloat controller;
	} SliderData;

	// Callback Functions
	static void submit_constraints(const NewtonJoint* joint, dgFloat32 timestep, int thread_index);
	static void get_info(const NewtonJoint* const joint, NewtonJointRecord* const info);
	static void on_destroy(JointData* joint_data);
	static void on_disconnect(JointData* joint_data);
	static void adjust_pin_matrix_proc(JointData* joint_data, dMatrix& pin_matrix);

	// Ruby Functions
	static VALUE is_valid(VALUE self, VALUE v_joint);
	static VALUE create(VALUE self, VALUE v_joint);
	static VALUE get_cur_position(VALUE self, VALUE v_joint);
	static VALUE get_cur_velocity(VALUE self, VALUE v_joint);
	static VALUE get_cur_acceleration(VALUE self, VALUE v_joint);
	static VALUE get_min(VALUE self, VALUE v_joint);
	static VALUE set_min(VALUE self, VALUE v_joint, VALUE v_min);
	static VALUE get_max(VALUE self, VALUE v_joint);
	static VALUE set_max(VALUE self, VALUE v_joint, VALUE v_max);
	static VALUE enable_limits(VALUE self, VALUE v_joint, VALUE v_state);
	static VALUE limits_enabled(VALUE self, VALUE v_joint);
	static VALUE get_friction(VALUE self, VALUE v_joint);
	static VALUE set_friction(VALUE self, VALUE v_joint, VALUE v_friction);
	static VALUE get_controller(VALUE self, VALUE v_joint);
	static VALUE set_controller(VALUE self, VALUE v_joint, VALUE v_controller);
};

void Init_msp_slider(VALUE mNewton);

#endif	/* MSP_SLIDER_H */
