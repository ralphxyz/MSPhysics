#ifndef MSP_PISTON_H
#define MSP_PISTON_H

#include "msp_util.h"
#include "msp_joint.h"

namespace MSNewton {
	class Piston;
}

class MSNewton::Piston {
private:
	// Variables
	static const dFloat DEFAULT_MIN;
	static const dFloat DEFAULT_MAX;
	static const bool DEFAULT_LIMITS_ENABLED;
	static const dFloat DEFAULT_RATE;
	static const dFloat DEFAULT_POWER;
	static const dFloat DEFAULT_REDUCTION_RATIO;
	static const dFloat DEFAULT_CONTROLLER;
	static const bool DEFAULT_CONTROLLER_ENABLED;

public:
	// Structures
	typedef struct PistonData
	{
		dFloat cur_pos;
		dFloat cur_vel;
		dFloat cur_accel;
		dFloat min;
		dFloat max;
		bool limits_enabled;
		dFloat rate;
		dFloat power;
		dFloat reduction_ratio;
		dFloat controller;
		bool controller_enabled;
	} PistonData;

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
	static VALUE get_rate(VALUE self, VALUE v_joint);
	static VALUE set_rate(VALUE self, VALUE v_joint, VALUE v_rate);
	static VALUE get_power(VALUE self, VALUE v_joint);
	static VALUE set_power(VALUE self, VALUE v_joint, VALUE v_power);
	static VALUE get_reduction_ratio(VALUE self, VALUE v_joint);
	static VALUE set_reduction_ratio(VALUE self, VALUE v_joint, VALUE v_reduction_ratio);
	static VALUE get_controller(VALUE self, VALUE v_joint);
	static VALUE set_controller(VALUE self, VALUE v_joint, VALUE v_controller);
};

void Init_msp_piston(VALUE mNewton);

#endif	/* MSP_PISTON_H */
