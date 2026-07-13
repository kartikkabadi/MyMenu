#!/usr/bin/env bash
# Generates MyMenu.xcodeproj from source tree (no xcodegen required).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJ="$ROOT/MyMenu.xcodeproj"
mkdir -p "$PROJ"

id() {
  printf '%s' "$1" | shasum -a 256 | cut -c1-24
}

PROJECT_ID=$(id project)
TARGET_ID=$(id target)
SOURCES_PHASE=$(id sources-phase)
FRAMEWORKS_PHASE=$(id frameworks-phase)
CORE_DISPLAY_REF=$(id core-display-reference)
CORE_DISPLAY_BUILD=$(id core-display-build)
PRODUCT_REF=$(id product-reference)
CONFIG_LIST_PROJ=$(id project-configuration-list)
CONFIG_LIST_TGT=$(id target-configuration-list)
DEBUG_CFG=$(id project-debug-configuration)
RELEASE_CFG=$(id project-release-configuration)
DEBUG_CFG_T=$(id target-debug-configuration)
RELEASE_CFG_T=$(id target-release-configuration)

# Collect Swift sources
SWIFT_FILES=()
while IFS= read -r file; do
  if [[ -n "$file" ]]; then
    SWIFT_FILES+=("$file")
  fi
done < <(find "$ROOT/MyMenu" -name '*.swift' | sort)
FILE_REFS=""
BUILD_FILES=""
SOURCES_FILES=""
GROUP_CHILDREN=""
for f in "${SWIFT_FILES[@]}"; do
  rel_to_group="${f#$ROOT/MyMenu/}"
  fid=$(id "file-reference:$rel_to_group")
  bid=$(id "build-file:$rel_to_group")
  FILE_REFS+="
		$fid /* $(basename "$f") */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"$rel_to_group\"; sourceTree = \"<group>\"; };"
  BUILD_FILES+="
		$bid /* $(basename "$f") in Sources */ = {isa = PBXBuildFile; fileRef = $fid /* $(basename "$f") */; };"
  SOURCES_FILES+="
				$bid /* $(basename "$f") in Sources */,"
  GROUP_CHILDREN+="
				$fid /* $(basename "$f") */,"
done

cat > "$PROJ/project.pbxproj" <<EOF
// !\$*UTF8*\$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {
$FILE_REFS
		$PRODUCT_REF /* MyMenu.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = MyMenu.app; sourceTree = BUILT_PRODUCTS_DIR; };
		$CORE_DISPLAY_REF /* CoreDisplay.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = CoreDisplay.framework; path = System/Library/Frameworks/CoreDisplay.framework; sourceTree = SDKROOT; };
		$CORE_DISPLAY_BUILD /* CoreDisplay.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = $CORE_DISPLAY_REF /* CoreDisplay.framework */; };
		INFO_PLIST /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
		ENTITLEMENTS /* MyMenu.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = MyMenu.entitlements; sourceTree = "<group>"; };
		BRIDGING /* Bridging-Header.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = "Bridging-Header.h"; sourceTree = "<group>"; };
$BUILD_FILES
		$TARGET_ID /* MyMenu */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = $CONFIG_LIST_TGT /* Build configuration list for PBXNativeTarget "MyMenu" */;
			buildPhases = (
				$SOURCES_PHASE /* Sources */,
				$FRAMEWORKS_PHASE /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = MyMenu;
			productName = MyMenu;
			productReference = $PRODUCT_REF /* MyMenu.app */;
			productType = "com.apple.product-type.application";
		};
		$PROJECT_ID /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2600;
				LastUpgradeCheck = 2600;
			};
			buildConfigurationList = $CONFIG_LIST_PROJ /* Build configuration list for PBXProject "MyMenu" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = GROUP_ROOT;
			productRefGroup = GROUP_PRODUCTS /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				$TARGET_ID /* MyMenu */,
			);
		};
		$SOURCES_PHASE /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
$SOURCES_FILES
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		$FRAMEWORKS_PHASE /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				$CORE_DISPLAY_BUILD /* CoreDisplay.framework in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		$DEBUG_CFG /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				MACOSX_DEPLOYMENT_TARGET = 26.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG \$(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		$RELEASE_CFG /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				MACOSX_DEPLOYMENT_TARGET = 26.0;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
			};
			name = Release;
		};
		$DEBUG_CFG_T /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_ENTITLEMENTS = MyMenu/MyMenu.entitlements;
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = MyMenu/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = "\$(inherited) @executable_path/../Frameworks";
				MARKETING_VERSION = 0.1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.mymenu.MyMenu;
				PRODUCT_NAME = "\$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_OBJC_BRIDGING_HEADER = "MyMenu/ThirdParty/Bridging-Header.h";
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		$RELEASE_CFG_T /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_ENTITLEMENTS = MyMenu/MyMenu.entitlements;
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = MyMenu/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = "\$(inherited) @executable_path/../Frameworks";
				MARKETING_VERSION = 0.1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.mymenu.MyMenu;
				PRODUCT_NAME = "\$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_OBJC_BRIDGING_HEADER = "MyMenu/ThirdParty/Bridging-Header.h";
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
		$CONFIG_LIST_PROJ /* Build configuration list for PBXProject "MyMenu" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				$DEBUG_CFG /* Debug */,
				$RELEASE_CFG /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		$CONFIG_LIST_TGT /* Build configuration list for PBXNativeTarget "MyMenu" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				$DEBUG_CFG_T /* Debug */,
				$RELEASE_CFG_T /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		GROUP_ROOT = {
			isa = PBXGroup;
			children = (
				GROUP_MYMENU /* MyMenu */,
				GROUP_PRODUCTS /* Products */,
			);
			sourceTree = "<group>";
		};
		GROUP_PRODUCTS /* Products */ = {
			isa = PBXGroup;
			children = (
				$PRODUCT_REF /* MyMenu.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
		GROUP_MYMENU /* MyMenu */ = {
			isa = PBXGroup;
			children = (
				INFO_PLIST /* Info.plist */,
				ENTITLEMENTS /* MyMenu.entitlements */,
$GROUP_CHILDREN
			);
			path = MyMenu;
			sourceTree = "<group>";
		};
	};
	rootObject = $PROJECT_ID /* Project object */;
}
EOF

echo "Generated $PROJ"
