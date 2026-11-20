#include <node_api.h>

static napi_value Hello(napi_env env, napi_callback_info info) {
  napi_value result;
  napi_create_int32(env, 42, &result);
  return result;
}

NAPI_MODULE_INIT() {
  napi_value fn;
  napi_create_function(env, "hello", NAPI_AUTO_LENGTH, Hello, NULL, &fn);
  napi_set_named_property(env, exports, "hello", fn);
  return exports;
}
