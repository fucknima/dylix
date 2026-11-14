from pathlib import Path
import subprocess,tempfile,os
root=Path(__file__).resolve().parents[1]
sdk=Path('/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk')
if not sdk.exists():sdk=Path(subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip())
with tempfile.TemporaryDirectory(prefix='dylix-agent-') as d:
 p=Path(d);exe=p/'test'
 files=['App/AI/Registry/TFAIToolRegistry.m','tests/AgentExtensionsTests.m','App/AI/Providers/TFAIRegistry.m','App/AI/Providers/TFAIProtocol.m','App/AI/Agent/TFAIAgentContext.m','App/AI/Agent/TFAIMCP.m','App/AI/Sandbox/TFAIISHRuntime.m','App/AI/Sandbox/TFAIISHRootCatalog.m','App/AI/Sandbox/TFAIISHEnvironment.m','App/AI/Sandbox/TFAIISHMCPTransport.m','App/AI/Permissions/TFAIPolicy.m','App/AI/Agent/TFAIBuildCheckpoint.m']
 subprocess.run(['xcrun','clang','-isysroot',str(sdk),'-fobjc-arc','-fblocks','-Wno-nullability-completeness',*[str(root/f) for f in files],'-lsqlite3','-framework','Foundation','-framework','Security','-o',str(exe)],check=True)
 env=dict(os.environ,DYLIX_PROVIDER_RESOURCES=str(root/'Resources/AIProviders'),DYLIX_SKILL_RESOURCES=str(root/'Resources/AgentSkills'))
 subprocess.run([str(exe),str(p/'project')],env=env,check=True)
