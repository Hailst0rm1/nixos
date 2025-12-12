// DLL Proxy with Command Execution
// Original DLL: {{ target_dll }}
// Command: {{ command }}
//
// This proxy DLL forwards all exports to the original DLL
// while executing a custom command on DLL_PROCESS_ATTACH

{{ modified_cpp }}
