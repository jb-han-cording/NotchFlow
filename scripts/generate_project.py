#!/usr/bin/env python3
"""Generate a dependency-free Xcode project with stable IDs from checked-in Swift sources."""
from pathlib import Path
import hashlib, plistlib
root = Path(__file__).resolve().parents[1]
objects = {}
def uid(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def put(key, value): objects[uid(key)] = value; return uid(key)
def quote(value): return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'
def render(value):
    if isinstance(value, dict): return '{ ' + ' '.join(f'{quote(k)} = {render(v)};' for k,v in value.items()) + ' }'
    if isinstance(value, list): return '(' + ', '.join(render(v) for v in value) + ')'
    return quote(value)
refs, builds = [], []
for file in sorted((root/'Sources').rglob('*.swift')):
    path = str(file.relative_to(root))
    text = file.read_text()
    if '\nimport NotchFlowCore\n' in text and '#if SWIFT_PACKAGE' not in text:
        file.write_text(text.replace('import NotchFlowCore', '#if SWIFT_PACKAGE\nimport NotchFlowCore\n#endif'))
    ref = put(path, dict(isa='PBXFileReference', lastKnownFileType='sourcecode.swift', path=path, sourceTree='<group>'))
    refs.append(ref)
    builds.append(put('build:'+path, dict(isa='PBXBuildFile', fileRef=ref)))
icon = put('appicon', dict(isa='PBXFileReference', lastKnownFileType='image.icns', path='Resources/AppIcon.icns', sourceTree='<group>'))
refs.append(icon)
iconbuild = put('build:appicon', dict(isa='PBXBuildFile', fileRef=icon))
resourcephase = put('resources', dict(isa='PBXResourcesBuildPhase', buildActionMask='2147483647', files=[iconbuild], runOnlyForDeploymentPostprocessing='0'))
product = put('product', dict(isa='PBXFileReference', explicitFileType='wrapper.application', path='NotchFlow.app', sourceTree='BUILT_PRODUCTS_DIR'))
products = put('products', dict(isa='PBXGroup', children=[product], name='Products', sourceTree='<group>'))
group = put('group', dict(isa='PBXGroup', children=refs+[products], sourceTree='<group>'))
sourcephase = put('sources', dict(isa='PBXSourcesBuildPhase', buildActionMask='2147483647', files=builds, runOnlyForDeploymentPostprocessing='0'))
frameworkphase = put('frameworks', dict(isa='PBXFrameworksBuildPhase', buildActionMask='2147483647', files=[], runOnlyForDeploymentPostprocessing='0'))
sparkle_package = put('package:Sparkle', dict(isa='XCRemoteSwiftPackageReference', repositoryURL='https://github.com/sparkle-project/Sparkle', requirement=dict(kind='upToNextMajorVersion', minimumVersion='2.10.0')))
sparkle_product = put('product:Sparkle', dict(isa='XCSwiftPackageProductDependency', package=sparkle_package, productName='Sparkle'))
configs = []; projectconfigs = []
for name in ['Debug', 'Release']:
    settings = dict(PRODUCT_BUNDLE_IDENTIFIER='local.NotchFlow', PRODUCT_NAME='$(TARGET_NAME)', SWIFT_VERSION='5.0', MACOSX_DEPLOYMENT_TARGET='14.0', INFOPLIST_FILE='Resources/Info.plist', GENERATE_INFOPLIST_FILE='NO', CODE_SIGN_ENTITLEMENTS='Resources/NotchFlow.entitlements', CODE_SIGN_STYLE='Automatic', ENABLE_HARDENED_RUNTIME='YES', ENABLE_APP_SANDBOX='NO', COMBINE_HIDPI_IMAGES='YES', LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/../Frameworks', SWIFT_OPTIMIZATION_LEVEL='-Onone' if name=='Debug' else '-O', SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG' if name=='Debug' else '', SWIFT_EMIT_LOC_STRINGS='NO')
    configs.append(put('app:'+name, dict(isa='XCBuildConfiguration', buildSettings=settings, name=name)))
    projectconfigs.append(put('project:'+name, dict(isa='XCBuildConfiguration', buildSettings=dict(SDKROOT='macosx', CLANG_ENABLE_MODULES='YES', MACOSX_DEPLOYMENT_TARGET='14.0'), name=name)))
configlist = put('configlist', dict(isa='XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible='0', defaultConfigurationName='Release'))
projectlist = put('projectlist', dict(isa='XCConfigurationList', buildConfigurations=projectconfigs, defaultConfigurationIsVisible='0', defaultConfigurationName='Release'))
target = put('target', dict(isa='PBXNativeTarget', buildConfigurationList=configlist, buildPhases=[sourcephase,frameworkphase,resourcephase], buildRules=[], dependencies=[], name='NotchFlow', packageProductDependencies=[sparkle_product], productName='NotchFlow', productReference=product, productType='com.apple.product-type.application'))
project = put('project', dict(isa='PBXProject', attributes=dict(LastUpgradeCheck='1600'), buildConfigurationList=projectlist, compatibilityVersion='Xcode 14.0', developmentRegion='en', knownRegions=['en','ko','Base'], mainGroup=group, packageReferences=[sparkle_package], productRefGroup=products, projectDirPath='', projectRoot='', targets=[target]))
folder = root/'NotchFlow.xcodeproj'; folder.mkdir(exist_ok=True)
(folder/'project.pbxproj').write_text('// !$*UTF8*$!\n'+render(dict(archiveVersion='1', classes={}, objectVersion='56', objects=objects, rootObject=project))+'\n')
schemes = folder/'xcshareddata/xcschemes'; schemes.mkdir(parents=True, exist_ok=True)
ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="NotchFlow.app" BlueprintName="NotchFlow" ReferencedContainer="container:NotchFlow.xcodeproj"/>'
(schemes/'NotchFlow.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug"/><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
