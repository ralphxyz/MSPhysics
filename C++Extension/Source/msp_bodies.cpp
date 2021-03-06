#include "msp_bodies.h"

/*
 ///////////////////////////////////////////////////////////////////////////////
  Ruby Functions
 ///////////////////////////////////////////////////////////////////////////////
*/

VALUE MSNewton::Bodies::aabb_overlap(VALUE self, VALUE v_body1, VALUE v_body2) {
	const NewtonBody* body1 = Util::value_to_body(v_body1);
	const NewtonBody* body2 = Util::value_to_body(v_body2);
	Util::validate_two_bodies(body1, body2);
	return Util::bodies_aabb_overlap(body1, body2) ? Qtrue : Qfalse;
}

VALUE MSNewton::Bodies::collidable(VALUE self, VALUE v_body1, VALUE v_body2) {
	const NewtonBody* body1 = Util::value_to_body(v_body1);
	const NewtonBody* body2 = Util::value_to_body(v_body2);
	Util::validate_two_bodies(body1, body2);
	return Util::bodies_collidable(body1, body2) ? Qtrue : Qfalse;
}

VALUE MSNewton::Bodies::touching(VALUE self, VALUE v_body1, VALUE v_body2) {
	const NewtonBody* body1 = Util::value_to_body(v_body1);
	const NewtonBody* body2 = Util::value_to_body(v_body2);
	Util::validate_two_bodies(body1, body2);
	const NewtonWorld* world = NewtonBodyGetWorld(body1);
	NewtonCollision* colA = NewtonBodyGetCollision(body1);
	NewtonCollision* colB = NewtonBodyGetCollision(body2);
	dMatrix matrixA;
	dMatrix matrixB;
	NewtonBodyGetMatrix(body1, &matrixA[0][0]);
	NewtonBodyGetMatrix(body2, &matrixB[0][0]);
	return NewtonCollisionIntersectionTest(world, colA, &matrixA[0][0], colB, &matrixB[0][0], 0) == 1 ? Qtrue : Qfalse;
}

VALUE MSNewton::Bodies::get_closest_points(VALUE self, VALUE v_body1, VALUE v_body2) {
	const NewtonBody* body1 = Util::value_to_body(v_body1);
	const NewtonBody* body2 = Util::value_to_body(v_body2);
	Util::validate_two_bodies(body1, body2);
	const NewtonWorld* world = NewtonBodyGetWorld(body1);
	WorldData* world_data = (WorldData*)NewtonWorldGetUserData(world);
	NewtonCollision* colA = NewtonBodyGetCollision(body1);
	NewtonCollision* colB = NewtonBodyGetCollision(body2);
	dMatrix matrixA;
	dMatrix matrixB;
	NewtonBodyGetMatrix(body1, &matrixA[0][0]);
	NewtonBodyGetMatrix(body2, &matrixB[0][0]);
	dVector pointA;
	dVector pointB;
	dVector normalAB;
	if (NewtonCollisionClosestPoint(world, colA, &matrixA[0][0], colB, &matrixB[0][0], &pointA[0], &pointB[0], &normalAB[0], 0) == 0)
		return Qnil;
	return rb_ary_new3(2, Util::point_to_value(pointA, world_data->inverse_scale), Util::point_to_value(pointB, world_data->inverse_scale));
}

VALUE MSNewton::Bodies::get_force_in_between(VALUE self, VALUE v_body1, VALUE v_body2) {
	const NewtonBody* body1 = Util::value_to_body(v_body1);
	const NewtonBody* body2 = Util::value_to_body(v_body2);
	Util::validate_two_bodies(body1, body2);
	dVector net_force(0.0f, 0.0f, 0.0f);
	for (NewtonJoint* joint = NewtonBodyGetFirstContactJoint(body1); joint; joint = NewtonBodyGetNextContactJoint(body1, joint)) {
		if (NewtonJointGetBody0(joint) == body2 || NewtonJointGetBody1(joint) == body2) {
			for (void* contact = NewtonContactJointGetFirstContact(joint); contact; contact = NewtonContactJointGetNextContact(joint, contact)) {
				NewtonMaterial* material = NewtonContactGetMaterial(contact);
				dVector force;
				NewtonMaterialGetContactForce(material, body1, &force[0]);
				net_force += force;
			}
		}
	}
	const NewtonWorld* world = NewtonBodyGetWorld(body1);
	WorldData* world_data = (WorldData*)NewtonWorldGetUserData(world);
	//BodyData* body1_data = (BodyData*)NewtonBodyGetUserData(body1);
	//BodyData* body2_data = (BodyData*)NewtonBodyGetUserData(body2);
	/*if (world_data->gravity_enabled && (body1_data->gravity_enabled || body2_data->gravity_enabled)) {
		for (int i = 0; i < 3; ++i)
			net_force[i] *= world_data->inverse_scale;
	}*/
	return Util::vector_to_value(net_force, world_data->inverse_scale4);
}


void Init_msp_bodies(VALUE mNewton) {
	VALUE mBodies = rb_define_module_under(mNewton, "Bodies");

	rb_define_module_function(mBodies, "aabb_overlap?", VALUEFUNC(MSNewton::Bodies::aabb_overlap), 2);
	rb_define_module_function(mBodies, "collidable?", VALUEFUNC(MSNewton::Bodies::collidable), 2);
	rb_define_module_function(mBodies, "touching?", VALUEFUNC(MSNewton::Bodies::touching), 2);
	rb_define_module_function(mBodies, "get_closest_points", VALUEFUNC(MSNewton::Bodies::get_closest_points), 2);
	rb_define_module_function(mBodies, "get_force_in_between", VALUEFUNC(MSNewton::Bodies::get_force_in_between), 2);
}
