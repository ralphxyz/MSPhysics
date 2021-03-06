#ifndef MSP_PLANE_H
#define MSP_PLANE_H

#include "msp_util.h"
#include "msp_joint.h"

namespace MSNewton {
	class Plane;
}

class MSNewton::Plane {
private:
	// Variables

public:
	// Structures
	typedef struct PlaneData {
	} PlaneData;

	// Callback Functions
	static void submit_constraints(const NewtonJoint* joint, dgFloat32 timestep, int thread_index);
	static void get_info(const NewtonJoint* const joint, NewtonJointRecord* const info);
	static void on_destroy(JointData* joint_data);
	static void on_connect(JointData* joint_data);
	static void on_disconnect(JointData* joint_data);

	// Ruby Functions
	static VALUE is_valid(VALUE self, VALUE v_joint);
	static VALUE create(VALUE self, VALUE v_joint);
};

void Init_msp_plane(VALUE mNewton);

#endif	/* MSP_PLANE_H */
