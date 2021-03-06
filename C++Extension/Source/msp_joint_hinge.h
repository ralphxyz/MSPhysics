#ifndef MSP_HINGE_H
#define MSP_HINGE_H

#include "msp_util.h"
#include "msp_joint.h"

namespace MSNewton {
	class Hinge;
}

class MSNewton::Hinge {
private:
	// Variables
	static const dFloat DEFAULT_MIN;
	static const dFloat DEFAULT_MAX;
	static const bool DEFAULT_LIMITS_ENABLED;
	static const bool DEFAULT_STRONG_MODE_ENABLED;
	static const dFloat DEFAULT_FRICTION;
	static const dFloat DEFAULT_ACCEL;
	static const dFloat DEFAULT_DAMP;
	static const bool DEFAULT_ROTATE_BACK_ENABLED;
	static const dFloat DEFAULT_START_ANGLE;
	static const dFloat DEFAULT_CONTROLLER;

public:
	// Structures
	typedef struct HingeData
	{
		AngularIntegration* ai;
		dFloat cur_omega;
		dFloat cur_accel;
		dFloat min;
		dFloat max;
		bool limits_enabled;
		bool strong_mode_enabled;
		dFloat friction;
		dFloat accel;
		dFloat damp;
		bool rotate_back_enabled;
		dFloat start_angle;
		dFloat controller;
		dFloat desired_start_angle;
		bool temp_disable_limits;
		NewtonJoint* sc;
	} HingeData;

	// Callback Functions
	static void submit_constraints(const NewtonJoint* joint, dgFloat32 timestep, int thread_index);
	static void sc_submit_constraints(const NewtonJoint* joint, dgFloat32 timestep, int thread_index);
	static void sc_get_info(const NewtonJoint* const joint, NewtonJointRecord* const info);
	static void sc_destructor(const NewtonJoint* joint);
	static void get_info(const NewtonJoint* const joint, NewtonJointRecord* const info);
	static void on_destroy(JointData* joint_data);
	static void on_connect(JointData* joint_data);
	static void on_disconnect(JointData* joint_data);
	static void adjust_pin_matrix_proc(JointData* joint_data, dMatrix& pin_matrix);

	// Ruby Functions
	static VALUE is_valid(VALUE self, VALUE v_joint);
	static VALUE create(VALUE self, VALUE v_joint);
	static VALUE get_cur_angle(VALUE self, VALUE v_joint);
	static VALUE get_cur_omega(VALUE self, VALUE v_joint);
	static VALUE get_cur_acceleration(VALUE self, VALUE v_joint);
	static VALUE get_min(VALUE self, VALUE v_joint);
	static VALUE set_min(VALUE self, VALUE v_joint, VALUE v_min);
	static VALUE get_max(VALUE self, VALUE v_joint);
	static VALUE set_max(VALUE self, VALUE v_joint, VALUE v_max);
	static VALUE get_friction(VALUE self, VALUE v_joint);
	static VALUE set_friction(VALUE self, VALUE v_joint, VALUE v_friction);
	static VALUE enable_limits(VALUE self, VALUE v_joint, VALUE v_state);
	static VALUE limits_enabled(VALUE self, VALUE v_joint);
	static VALUE enable_strong_mode(VALUE self, VALUE v_joint, VALUE v_state);
	static VALUE strong_mode_enabled(VALUE self, VALUE v_joint);
	static VALUE get_accel(VALUE self, VALUE v_joint);
	static VALUE set_accel(VALUE self, VALUE v_joint, VALUE v_accel);
	static VALUE get_damp(VALUE self, VALUE v_joint);
	static VALUE set_damp(VALUE self, VALUE v_joint, VALUE v_damp);
	static VALUE enable_rotate_back(VALUE self, VALUE v_joint, VALUE v_state);
	static VALUE rotate_back_enabled(VALUE self, VALUE v_joint);
	static VALUE get_start_angle(VALUE self, VALUE v_joint);
	static VALUE set_start_angle(VALUE self, VALUE v_joint, VALUE v_angle);
	static VALUE get_controller(VALUE self, VALUE v_joint);
	static VALUE set_controller(VALUE self, VALUE v_joint, VALUE v_controller);
};

void Init_msp_hinge(VALUE mNewton);

#endif	/* MSP_HINGE_H */
