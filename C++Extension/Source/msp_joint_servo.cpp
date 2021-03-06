#include "msp_joint_servo.h"

/*
 ///////////////////////////////////////////////////////////////////////////////
  Variables
 ///////////////////////////////////////////////////////////////////////////////
*/

const dFloat MSNewton::Servo::DEFAULT_MIN = -180.0f * DEG_TO_RAD;
const dFloat MSNewton::Servo::DEFAULT_MAX = 180.0f * DEG_TO_RAD;
const bool MSNewton::Servo::DEFAULT_LIMITS_ENABLED = false;
const dFloat MSNewton::Servo::DEFAULT_RATE = 360.0f * DEG_TO_RAD;
const dFloat MSNewton::Servo::DEFAULT_POWER = 0.0f;
const dFloat MSNewton::Servo::DEFAULT_REDUCTION_RATIO = 0.1f;
const dFloat MSNewton::Servo::DEFAULT_CONTROLLER = 0.0f;
const bool MSNewton::Servo::DEFAULT_CONTROLLER_ENABLED = false;


/*
 ///////////////////////////////////////////////////////////////////////////////
  Callback Functions
 ///////////////////////////////////////////////////////////////////////////////
*/

void MSNewton::Servo::submit_constraints(const NewtonJoint* joint, dgFloat32 timestep, int thread_index) {
	JointData* joint_data = (JointData*)NewtonJointGetUserData(joint);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;

	// Calculate position of pivot points and Jacobian direction vectors in global space.
	dMatrix matrix0, matrix1, matrix2;
	MSNewton::Joint::c_calculate_global_matrix(joint_data, matrix0, matrix1, matrix2);

	// Calculate angle, omega, and acceleration.
	dFloat last_angle = cj_data->ai->get_angle();
	dFloat last_omega = cj_data->cur_omega;
	dFloat sin_angle;
	dFloat cos_angle;
	Joint::c_calculate_angle(matrix1.m_front, matrix0.m_front, matrix0.m_right, sin_angle, cos_angle);
	cj_data->ai->update(cos_angle, sin_angle);
	cj_data->cur_omega = (cj_data->ai->get_angle() - last_angle) / timestep;
	cj_data->cur_accel = (cj_data->cur_omega - last_omega) / timestep;
	dFloat cur_angle = cj_data->ai->get_angle();

	// Restrict movement on the pivot point along all tree orthonormal directions.
	NewtonUserJointAddLinearRow(joint, &matrix0.m_posit[0], &matrix1.m_posit[0], &matrix0.m_front[0]);
	if (joint_data->ctype == CT_FLEXIBLE)
		NewtonUserJointSetRowSpringDamperAcceleration(joint, Joint::LINEAR_STIFF, Joint::LINEAR_DAMP);
	else if (joint_data->ctype == CT_ROBUST)
		NewtonUserJointSetRowAcceleration(joint, NewtonUserCalculateRowZeroAccelaration(joint));
	NewtonUserJointSetRowStiffness(joint, joint_data->stiffness);

	NewtonUserJointAddLinearRow(joint, &matrix0.m_posit[0], &matrix1.m_posit[0], &matrix0.m_up[0]);
	if (joint_data->ctype == CT_FLEXIBLE)
		NewtonUserJointSetRowSpringDamperAcceleration(joint, Joint::LINEAR_STIFF, Joint::LINEAR_DAMP);
	else if (joint_data->ctype == CT_ROBUST)
		NewtonUserJointSetRowAcceleration(joint, NewtonUserCalculateRowZeroAccelaration(joint));
	NewtonUserJointSetRowStiffness(joint, joint_data->stiffness);

	NewtonUserJointAddLinearRow(joint, &matrix0.m_posit[0], &matrix1.m_posit[0], &matrix0.m_right[0]);
	if (joint_data->ctype == CT_FLEXIBLE)
		NewtonUserJointSetRowSpringDamperAcceleration(joint, Joint::LINEAR_STIFF, Joint::LINEAR_DAMP);
	else if (joint_data->ctype == CT_ROBUST)
		NewtonUserJointSetRowAcceleration(joint, NewtonUserCalculateRowZeroAccelaration(joint));
	NewtonUserJointSetRowStiffness(joint, joint_data->stiffness);

	// Add two rows to restrict rotation around the the axis perpendicular to the rotation axis.
	/*NewtonUserJointAddAngularRow(joint, Joint::c_calculate_angle(matrix0.m_right, matrix1.m_right, matrix0.m_front), &matrix0.m_front[0]);
	if (joint_data->ctype == CT_FLEXIBLE)
		NewtonUserJointSetRowSpringDamperAcceleration(joint, Joint::ANGULAR_STIFF, Joint::ANGULAR_DAMP);
	else if (joint_data->ctype == CT_ROBUST)
		NewtonUserJointSetRowAcceleration(joint, NewtonUserCalculateRowZeroAccelaration(joint));
	NewtonUserJointSetRowStiffness(joint, joint_data->stiffness);

	NewtonUserJointAddAngularRow(joint, Joint::c_calculate_angle(matrix0.m_right, matrix1.m_right, matrix0.m_up), &matrix0.m_up[0]);
	if (joint_data->ctype == CT_FLEXIBLE)
		NewtonUserJointSetRowSpringDamperAcceleration(joint, Joint::ANGULAR_STIFF, Joint::ANGULAR_DAMP);
	else if (joint_data->ctype == CT_ROBUST)
		NewtonUserJointSetRowAcceleration(joint, NewtonUserCalculateRowZeroAccelaration(joint));
	NewtonUserJointSetRowStiffness(joint, joint_data->stiffness);*/

	// Add two more rows to achieve a more robust angular constraint.
	// Get a point along the pin axis at some reasonable large distance from the pivot.
	dVector q0(matrix0.m_posit + matrix0.m_right.Scale(MIN_JOINT_PIN_LENGTH));
	dVector q1(matrix1.m_posit + matrix1.m_right.Scale(MIN_JOINT_PIN_LENGTH));

	// Add two constraints row perpendicular to the pin vector.
	NewtonUserJointAddLinearRow(joint, &q0[0], &q1[0], &matrix1.m_front[0]);
	if (joint_data->ctype == CT_FLEXIBLE)
		NewtonUserJointSetRowSpringDamperAcceleration(joint, Joint::ANGULAR_STIFF, Joint::ANGULAR_DAMP);
	else if (joint_data->ctype == CT_ROBUST)
		NewtonUserJointSetRowAcceleration(joint, NewtonUserCalculateRowZeroAccelaration(joint));
	NewtonUserJointSetRowStiffness(joint, joint_data->stiffness);

	NewtonUserJointAddLinearRow(joint, &q0[0], &q1[0], &matrix1.m_up[0]);
	if (joint_data->ctype == CT_FLEXIBLE)
		NewtonUserJointSetRowSpringDamperAcceleration(joint, Joint::ANGULAR_STIFF, Joint::ANGULAR_DAMP);
	else if (joint_data->ctype == CT_ROBUST)
		NewtonUserJointSetRowAcceleration(joint, NewtonUserCalculateRowZeroAccelaration(joint));
	NewtonUserJointSetRowStiffness(joint, joint_data->stiffness);

	// Add limits and friction
	if (cj_data->limits_enabled == true && cur_angle < cj_data->min - Joint::ANGULAR_LIMIT_EPSILON) {
		dFloat rel_angle = cj_data->min - cur_angle;
		NewtonUserJointAddAngularRow(joint, rel_angle, &matrix0.m_right[0]);
		NewtonUserJointSetRowMinimumFriction(joint, 0.0f);
		if (joint_data->ctype == CT_FLEXIBLE)
			NewtonUserJointSetRowSpringDamperAcceleration(joint, Joint::ANGULAR_STIFF, Joint::ANGULAR_DAMP);
		else if (joint_data->ctype == CT_ROBUST)
			NewtonUserJointSetRowAcceleration(joint, NewtonUserCalculateRowZeroAccelaration(joint));
		NewtonUserJointSetRowStiffness(joint, joint_data->stiffness);
	}
	else if (cj_data->limits_enabled == true && cur_angle > cj_data->max + Joint::ANGULAR_LIMIT_EPSILON) {
		dFloat rel_angle = cj_data->max - cur_angle;
		NewtonUserJointAddAngularRow(joint, rel_angle, &matrix0.m_right[0]);
		NewtonUserJointSetRowMaximumFriction(joint, 0.0f);
		if (joint_data->ctype == CT_FLEXIBLE)
			NewtonUserJointSetRowSpringDamperAcceleration(joint, Joint::ANGULAR_STIFF, Joint::ANGULAR_DAMP);
		else if (joint_data->ctype == CT_ROBUST)
			NewtonUserJointSetRowAcceleration(joint, NewtonUserCalculateRowZeroAccelaration(joint));
		NewtonUserJointSetRowStiffness(joint, joint_data->stiffness);
	}
	else {
		if (cj_data->controller_enabled) {
			// Get relative angular velocity
			dVector omega0(0.0f, 0.0f, 0.0f);
			dVector omega1(0.0f, 0.0f, 0.0f);
			NewtonBodyGetOmega(joint_data->child, &omega0[0]);
			if (joint_data->parent != nullptr)
				NewtonBodyGetOmega(joint_data->parent, &omega1[0]);
			dFloat rel_omega = (omega0 - omega1) % matrix1.m_right;
			// Calculate relative angle
			dFloat desired_angle = cj_data->limits_enabled ? Util::clamp(cj_data->controller, cj_data->min, cj_data->max) : cj_data->controller;
			dFloat rel_angle = desired_angle - cur_angle;
			dFloat arel_angle = dAbs(rel_angle);
			// Calculate desired accel
			dFloat mar = cj_data->rate * cj_data->reduction_ratio;
			dFloat ratio = (cj_data->rate > EPSILON && cj_data->reduction_ratio > EPSILON && arel_angle < mar) ? arel_angle / mar : 1.0f;
			dFloat step = cj_data->rate * ratio * dSign(rel_angle) * timestep;
			if (dAbs(step) > arel_angle) step = rel_angle;
			dFloat desired_omega = step / timestep;
			dFloat desired_accel = (desired_omega - rel_omega) / timestep;
			// Add angular row
			NewtonUserJointAddAngularRow(joint, step, &matrix0.m_right[0]);
			// Apply acceleration
			NewtonUserJointSetRowAcceleration(joint, desired_accel);
		}
		else {
			// Add angular row
			NewtonUserJointAddAngularRow(joint, 0.0f, &matrix1.m_right[0]);
		}
		if (cj_data->power == 0.0f) {
			NewtonUserJointSetRowMinimumFriction(joint, -Joint::CUSTOM_LARGE_VALUE);
			NewtonUserJointSetRowMaximumFriction(joint, Joint::CUSTOM_LARGE_VALUE);
		}
		else {
			NewtonUserJointSetRowMinimumFriction(joint, -cj_data->power);
			NewtonUserJointSetRowMaximumFriction(joint, cj_data->power);
		}
		NewtonUserJointSetRowStiffness(joint, joint_data->stiffness);
	}
}

void MSNewton::Servo::get_info(const NewtonJoint* const joint, NewtonJointRecord* const info) {
	JointData* joint_data = (JointData*)NewtonJointGetUserData(joint);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;

	info->m_minLinearDof[0] = -0.0f;
	info->m_maxLinearDof[0] = 0.0f;
	info->m_minLinearDof[1] = -0.0f;
	info->m_maxLinearDof[1] = 0.0f;
	info->m_minLinearDof[2] = -0.0f;
	info->m_maxLinearDof[2] = 0.0f;

	info->m_minAngularDof[0] = -0.0f;
	info->m_maxAngularDof[0] = 0.0f;
	info->m_minAngularDof[1] = -0.0f;
	info->m_maxAngularDof[1] = 0.0f;

	if (cj_data->limits_enabled) {
		info->m_minAngularDof[2] = (cj_data->min - cj_data->ai->get_angle()) * RAD_TO_DEG;
		info->m_maxAngularDof[2] = (cj_data->max - cj_data->ai->get_angle()) * RAD_TO_DEG;
	}
	else {
		info->m_minAngularDof[2] = -Joint::CUSTOM_LARGE_VALUE;
		info->m_maxAngularDof[2] = Joint::CUSTOM_LARGE_VALUE;
	}
}

void MSNewton::Servo::on_destroy(JointData* joint_data) {
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	delete cj_data->ai;
	delete cj_data;
}

void MSNewton::Servo::on_disconnect(JointData* joint_data) {
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	cj_data->ai->set_angle(0.0f);
	cj_data->cur_omega = 0.0f;
	cj_data->cur_accel = 0.0f;
}

void MSNewton::Servo::adjust_pin_matrix_proc(JointData* joint_data, dMatrix& pin_matrix) {
	dMatrix matrix;
	dVector centre;
	NewtonBodyGetMatrix(joint_data->child, &matrix[0][0]);
	NewtonBodyGetCentreOfMass(joint_data->child, &centre[0]);
	centre = matrix.TransformVector(centre);
	centre = pin_matrix.UntransformVector(centre);
	dVector point(0.0f, 0.0f, centre.m_z);
	pin_matrix.m_posit = pin_matrix.TransformVector(point);
}


/*
 ///////////////////////////////////////////////////////////////////////////////
  Ruby Functions
 ///////////////////////////////////////////////////////////////////////////////
*/

VALUE MSNewton::Servo::is_valid(VALUE self, VALUE v_joint) {
	JointData* address = (JointData*)Util::value_to_ll(v_joint);
	bool valid = Util::is_joint_valid(address);
	if (valid && address->jtype != JT_SERVO) valid = false;
	return Util::to_value(valid);
}

VALUE MSNewton::Servo::create(VALUE self, VALUE v_joint) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_NONE);

	ServoData* cj_data = new ServoData;
	cj_data->min = DEFAULT_MIN;
	cj_data->max = DEFAULT_MAX;
	cj_data->limits_enabled = DEFAULT_LIMITS_ENABLED;
	cj_data->rate = DEFAULT_RATE;
	cj_data->power = DEFAULT_POWER;
	cj_data->reduction_ratio = DEFAULT_REDUCTION_RATIO;
	cj_data->ai = new AngularIntegration();
	cj_data->cur_omega = 0.0f;
	cj_data->cur_accel = 0.0f;
	cj_data->controller = DEFAULT_CONTROLLER;
	cj_data->controller_enabled = DEFAULT_CONTROLLER_ENABLED;

	joint_data->dof = 6;
	joint_data->jtype = JT_SERVO;
	joint_data->cj_data = cj_data;
	joint_data->submit_constraints = submit_constraints;
	joint_data->get_info = get_info;
	joint_data->on_destroy = on_destroy;
	joint_data->on_disconnect = on_disconnect;
	//~ joint_data->adjust_pin_matrix_proc = adjust_pin_matrix_proc;

	return Util::to_value(joint_data);
}

VALUE MSNewton::Servo::get_cur_angle(VALUE self, VALUE v_joint) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	return Util::to_value(cj_data->ai->get_angle());
}

VALUE MSNewton::Servo::get_cur_omega(VALUE self, VALUE v_joint) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	return Util::to_value(cj_data->cur_omega);
}

VALUE MSNewton::Servo::get_cur_acceleration(VALUE self, VALUE v_joint) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	return Util::to_value(cj_data->cur_accel);
}

VALUE MSNewton::Servo::get_min(VALUE self, VALUE v_joint) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	return Util::to_value(cj_data->min);
}

VALUE MSNewton::Servo::set_min(VALUE self, VALUE v_joint, VALUE v_min) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	cj_data->min = Util::value_to_dFloat(v_min);
	return Util::to_value(cj_data->min);
}

VALUE MSNewton::Servo::get_max(VALUE self, VALUE v_joint) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	return Util::to_value(cj_data->max);
}

VALUE MSNewton::Servo::set_max(VALUE self, VALUE v_joint, VALUE v_max) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	cj_data->max = Util::value_to_dFloat(v_max);
	return Util::to_value(cj_data->max);
}

VALUE MSNewton::Servo::enable_limits(VALUE self, VALUE v_joint, VALUE v_state) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	cj_data->limits_enabled = Util::value_to_bool(v_state);
	return Util::to_value(cj_data->limits_enabled);
}

VALUE MSNewton::Servo::limits_enabled(VALUE self, VALUE v_joint) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	return Util::to_value(cj_data->limits_enabled);
}

VALUE MSNewton::Servo::get_rate(VALUE self, VALUE v_joint) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	return Util::to_value(cj_data->rate);
}

VALUE MSNewton::Servo::set_rate(VALUE self, VALUE v_joint, VALUE v_rate) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	cj_data->rate = Util::clamp_min(Util::value_to_dFloat(v_rate), 0.0f);
	return Util::to_value(cj_data->rate);
}

VALUE MSNewton::Servo::get_power(VALUE self, VALUE v_joint) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	WorldData* world_data = (WorldData*)NewtonWorldGetUserData(joint_data->world);
	return Util::to_value(cj_data->power * world_data->inverse_scale5);
}

VALUE MSNewton::Servo::set_power(VALUE self, VALUE v_joint, VALUE v_power) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	WorldData* world_data = (WorldData*)NewtonWorldGetUserData(joint_data->world);
	cj_data->power = Util::clamp_min(Util::value_to_dFloat(v_power), 0.0f) * world_data->scale5;
	return Util::to_value(cj_data->power * world_data->inverse_scale5);
}

VALUE MSNewton::Servo::get_reduction_ratio(VALUE self, VALUE v_joint) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	return Util::to_value(cj_data->reduction_ratio);
}

VALUE MSNewton::Servo::set_reduction_ratio(VALUE self, VALUE v_joint, VALUE v_reduction_ratio) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	cj_data->reduction_ratio = Util::clamp(Util::value_to_dFloat(v_reduction_ratio), 0.0f, 1.0f);
	return Util::to_value(cj_data->reduction_ratio);
}

VALUE MSNewton::Servo::get_controller(VALUE self, VALUE v_joint) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	return (cj_data->controller_enabled ? Util::to_value(cj_data->controller) : Qnil);
}

VALUE MSNewton::Servo::set_controller(VALUE self, VALUE v_joint, VALUE v_controller) {
	JointData* joint_data = Util::value_to_joint2(v_joint, JT_SERVO);
	ServoData* cj_data = (ServoData*)joint_data->cj_data;
	if (v_controller == Qnil) {
		if (cj_data->controller_enabled == true) {
			cj_data->controller_enabled = false;
			if (joint_data->connected)
				NewtonBodySetSleepState(joint_data->child, 0);
		}
		return Qnil;
	}
	else {
		dFloat controller = Util::value_to_dFloat(v_controller);
		if (cj_data->controller_enabled == false || controller != cj_data->controller) {
			cj_data->controller_enabled = true;
			cj_data->controller = controller;
			if (joint_data->connected)
				NewtonBodySetSleepState(joint_data->child, 0);
		}
		return Util::to_value(cj_data->controller);
	}
}


void Init_msp_servo(VALUE mNewton) {
	VALUE mServo = rb_define_module_under(mNewton, "Servo");

	rb_define_module_function(mServo, "is_valid?", VALUEFUNC(MSNewton::Servo::is_valid), 1);
	rb_define_module_function(mServo, "create", VALUEFUNC(MSNewton::Servo::create), 1);
	rb_define_module_function(mServo, "get_cur_angle", VALUEFUNC(MSNewton::Servo::get_cur_angle), 1);
	rb_define_module_function(mServo, "get_cur_omega", VALUEFUNC(MSNewton::Servo::get_cur_omega), 1);
	rb_define_module_function(mServo, "get_cur_acceleration", VALUEFUNC(MSNewton::Servo::get_cur_acceleration), 1);
	rb_define_module_function(mServo, "get_min", VALUEFUNC(MSNewton::Servo::get_min), 1);
	rb_define_module_function(mServo, "set_min", VALUEFUNC(MSNewton::Servo::set_min), 2);
	rb_define_module_function(mServo, "get_max", VALUEFUNC(MSNewton::Servo::get_max), 1);
	rb_define_module_function(mServo, "set_max", VALUEFUNC(MSNewton::Servo::set_max), 2);
	rb_define_module_function(mServo, "enable_limits", VALUEFUNC(MSNewton::Servo::enable_limits), 2);
	rb_define_module_function(mServo, "limits_enabled?", VALUEFUNC(MSNewton::Servo::limits_enabled), 1);
	rb_define_module_function(mServo, "get_rate", VALUEFUNC(MSNewton::Servo::get_rate), 1);
	rb_define_module_function(mServo, "set_rate", VALUEFUNC(MSNewton::Servo::set_rate), 2);
	rb_define_module_function(mServo, "get_power", VALUEFUNC(MSNewton::Servo::get_power), 1);
	rb_define_module_function(mServo, "set_power", VALUEFUNC(MSNewton::Servo::set_power), 2);
	rb_define_module_function(mServo, "get_reduction_ratio", VALUEFUNC(MSNewton::Servo::get_reduction_ratio), 1);
	rb_define_module_function(mServo, "set_reduction_ratio", VALUEFUNC(MSNewton::Servo::set_reduction_ratio), 2);
	rb_define_module_function(mServo, "get_controller", VALUEFUNC(MSNewton::Servo::get_controller), 1);
	rb_define_module_function(mServo, "set_controller", VALUEFUNC(MSNewton::Servo::set_controller), 2);
}
