# ----------------------------------------------------------------------------
#
# Ubpa_AddDep(<dep-list>)
#
# ----------------------------------------------------------------------------
#
# Ubpa_Export([INC <inc>])
# - export some files
# - inc: default ON, install include/
#
# ----------------------------------------------------------------------------

message(STATUS "include UbpaPackage.cmake")

set(_Ubpa_Package_have_dependencies 0)

function(Ubpa_DecodeVersion major minor patch version)
	if("${version}" MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)")
		set(${major} "${CMAKE_MATCH_1}" PARENT_SCOPE)
		set(${minor} "${CMAKE_MATCH_2}" PARENT_SCOPE)
		set(${patch} "${CMAKE_MATCH_3}" PARENT_SCOPE)
	elseif("${version}" MATCHES "^([0-9]+)\\.([0-9]+)")
		set(${major} "${CMAKE_MATCH_1}" PARENT_SCOPE)
		set(${minor} "${CMAKE_MATCH_2}" PARENT_SCOPE)
		set(${patch} "" PARENT_SCOPE)
	else()
		set(${major} "${CMAKE_MATCH_1}" PARENT_SCOPE)
		set(${minor} "" PARENT_SCOPE)
		set(${patch} "" PARENT_SCOPE)
	endif()
endfunction()

function(Ubpa_ToPackageName rst name version)
	set(tmp "${name}_${version}")
	string(REPLACE "." "_" tmp ${tmp})
	set(${rst} "${tmp}" PARENT_SCOPE)
endfunction()

function(Ubpa_PackageName rst)
	Ubpa_ToPackageName(tmp ${PROJECT_NAME} ${PROJECT_VERSION})
	set(${rst} ${tmp} PARENT_SCOPE)
endfunction()

macro(Ubpa_AddDep name version)
	set(_Ubpa_Package_have_dependencies 1)
	list(FIND _Ubpa_Package_dep_name_list "${name}" _idx)
	if("${_idx}" STREQUAL "-1")
	    message(STATUS "start add dependence ${name} v${version}")
		set(_need_find TRUE)
	else()
		set(_A_version "${${name}_VERSION}")
		set(_B_version "${version}")
		Ubpa_DecodeVersion(_A_major _A_minor _A_patch "${_A_version}")
		Ubpa_DecodeVersion(_B_major _B_minor _B_patch "${_B_version}")
		if(("${_A_major}" STREQUAL "${_B_major}") AND ("${_A_minor}" STREQUAL "${_B_minor}"))
			message(STATUS "Diamond dependence of ${name} with compatible version: ${_A_version} and ${_B_version}")
			if("${_A_major}" LESS "${_B_major}")
				list(REMOVE_AT _Ubpa_Package_dep_name_list ${_idx})
				list(REMOVE_AT _Ubpa_Package_dep_version_list ${_idx})
				set(_need_find TRUE)
			else()
				set(_need_find FALSE)
			endif()
		else()
			message(FATAL_ERROR "Diamond dependence of ${name} with incompatible version: ${_A_version} and ${_B_version}")
		endif()
	endif()
	if("${_need_find}" STREQUAL TRUE)
		list(APPEND _Ubpa_Package_dep_name_list ${name})
		list(APPEND _Ubpa_Package_dep_version_list ${version})
		message(STATUS "find package: ${name} v${version}")
		find_package(${name} ${version} QUIET)
		if(${${name}_FOUND})
			message(STATUS "${name} v${${name}_VERSION} found")
		else()
			set(_address "https://github.com/Ubpa/${name}")
			message(STATUS "${name} v${version} not found, so fetch it ..."
			"fetch: ${_address} with tag v${version}")
			FetchContent_Declare(
			  ${name}
			  GIT_REPOSITORY ${_address}
			  GIT_TAG "v${version}"
			)
			message(STATUS "${name} v${version} fetch done, building ...")
			FetchContent_MakeAvailable(${name})
			message(STATUS "${name} v${version} build done")
		endif()
	endif()
endmacro()

macro(Ubpa_Export)
	cmake_parse_arguments("ARG" "" "TARGET" "DIRECTORIES" ${ARGN})
	
	Ubpa_PackageName(package_name)
	message(STATUS "${package_name}")
	message(STATUS "export ${package_name}")
	
	if(${_Ubpa_Package_have_dependencies})
		set(UBPA_PACKAGE_INIT "
if(NOT \${FetchContent_FOUND})
	include(FetchContent)
endif()
if(NOT \${UCMake_FOUND})
	message(STATUS \"find package: UCMake v${UCMake_VERSION}\")
	find_package(UCMake ${UCMake_VERSION} QUIET)
	if(\${UCMake_FOUND})
		message(STATUS \"UCMake v\${UCMake_VERSION} found\")
	else()
		set(_Ubpa_Package_address \"https://github.com/Ubpa/UCMake\")
		message(STATUS \"UCMake v${UCMake_VERSION} not found, so fetch it ...\")
		message(STATUS \"fetch: \${_Ubpa_Package_address} with tag v${UCMake_VERSION}\")
		FetchContent_Declare(
		  UCMake
		  GIT_REPOSITORY \${_Ubpa_Package_address}
		  GIT_TAG \"v${UCMake_VERSION}\"
		)
		message(STATUS \"UCMake v${UCMake_VERSION} fetch done, building ...\")
		FetchContent_MakeAvailable(UCMake)
		message(STATUS \"UCMake v${UCMake_VERSION} build done\")
	endif()
endif()

if(MSVC)
	if(EXISTS \"\${CMAKE_CURRENT_LIST_DIR}/${package_name}.natvis\")
		if(NOT \"\${EXIST_UBPA_NATVIS_EXE}\")
			file(WRITE \"\${CMAKE_CURRENT_BINARY_DIR}/NatvisEmpty.cpp\" \"// generated by UCMake for natvis\\nint main(){ return 0; }\\n\")
			add_executable(Ubpa_natvis \"\${CMAKE_CURRENT_BINARY_DIR}/NatvisEmpty.cpp\")
			set(EXIST_UBPA_NATVIS_EXE \"ON\")
		endif()
		target_sources(Ubpa_natvis PRIVATE \"\${CMAKE_CURRENT_LIST_DIR}/${package_name}.natvis\")
	endif()
endif()
")
		message(STATUS "[Dependencies]")
		list(LENGTH _Ubpa_Package_dep_name_list _Ubpa_Package_dep_num)
		math(EXPR _Ubpa_Package_stop "${_Ubpa_Package_dep_num}-1")
		foreach(index RANGE ${_Ubpa_Package_stop})
			list(GET _Ubpa_Package_dep_name_list ${index} dep_name)
			list(GET _Ubpa_Package_dep_version_list ${index} dep_version)
			message(STATUS "- ${dep_name} v${dep_version}")
			set(UBPA_PACKAGE_INIT "${UBPA_PACKAGE_INIT}\nUbpa_AddDep(${dep_name} ${dep_version})")
		endforeach()
	endif()
	
	if(NOT "${ARG_TARGET}" STREQUAL "OFF")
		# generate the export targets for the build tree
		# needs to be after the install(TARGETS ) command
		export(EXPORT "${PROJECT_NAME}Targets"
			NAMESPACE "Ubpa::"
		#	#FILE "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Targets.cmake"
		)
		
		# install the configuration targets
		install(EXPORT "${PROJECT_NAME}Targets"
			FILE "${PROJECT_NAME}Targets.cmake"
			NAMESPACE "Ubpa::"
			DESTINATION "${package_name}/cmake"
		)
	endif()
	
	include(CMakePackageConfigHelpers)
	# generate the config file that is includes the exports
	configure_package_config_file(${PROJECT_SOURCE_DIR}/config/Config.cmake.in
		"${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
		INSTALL_DESTINATION "${package_name}/cmake"
		NO_SET_AND_CHECK_MACRO
		NO_CHECK_REQUIRED_COMPONENTS_MACRO
	)
	
	# generate the version file for the config file
	write_basic_package_version_file(
		"${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
		VERSION ${PROJECT_VERSION}
		COMPATIBILITY SameMinorVersion
	)

	# install the configuration file
	install(FILES
		"${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
		"${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
		DESTINATION "${package_name}/cmake"
	)
	
	foreach(dir ${ARG_DIRECTORIES})
		string(REGEX MATCH "(.*)/" prefix ${dir})
		if("${CMAKE_MATCH_1}" STREQUAL "")
			set(_destination "${package_name}")
		else()
			set(_destination "${package_name}/${CMAKE_MATCH_1}")
		endif()
		install(DIRECTORY ${dir} DESTINATION "${_destination}")
	endforeach()
endmacro()
