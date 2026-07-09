/// One raw motion reading: the accelerometer's gravity-included vector in the
/// Android sign convention (m/s^2-ish; the TiltProcessor only uses ratios, so
/// absolute units do not matter).
typedef MotionSample = ({double x, double y, double z});
