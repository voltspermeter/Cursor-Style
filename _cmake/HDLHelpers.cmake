#------------------------------------------------------------------------------
#
# HDLHelpers.cmake - CMake functions for HDL source management
#
# This module provides functions to register HDL sources and track dependencies
# between modules for use with various HDL simulators.
#
#------------------------------------------------------------------------------

# Global properties to track HDL modules
define_property(GLOBAL PROPERTY HDL_MODULES
    BRIEF_DOCS "List of all registered HDL modules"
    FULL_DOCS "Contains the names of all HDL modules registered with add_hdl_source")

define_property(GLOBAL PROPERTY HDL_MODULE_SOURCES
    BRIEF_DOCS "Map of module names to source files"
    FULL_DOCS "Property HDL_MODULE_<name>_SOURCES contains source file for module")

define_property(GLOBAL PROPERTY HDL_MODULE_DEPS
    BRIEF_DOCS "Map of module names to dependencies"
    FULL_DOCS "Property HDL_MODULE_<name>_DEPS contains dependencies for module")

# Initialize global module list
set_property(GLOBAL PROPERTY HDL_MODULES "")

#------------------------------------------------------------------------------
# add_hdl_source(<source_file> [DEPENDS <dep1> <dep2> ...])
#
# Register an HDL source file as a module.
#
# Arguments:
#   source_file  - The Verilog/SystemVerilog source file
#   DEPENDS      - List of module dependencies (other modules this one instantiates)
#
# The module name is derived from the source file name without extension.
#
# Example:
#   add_hdl_source(async_fifo.v DEPENDS sync_reg)
#
#------------------------------------------------------------------------------
function(add_hdl_source SOURCE_FILE)
    # Parse arguments
    cmake_parse_arguments(ARG "" "" "DEPENDS" ${ARGN})

    # Get module name from filename (without extension)
    get_filename_component(MODULE_NAME ${SOURCE_FILE} NAME_WE)

    # Get absolute path to source file
    get_filename_component(SOURCE_PATH ${SOURCE_FILE} ABSOLUTE)

    # Check if source file exists
    if(NOT EXISTS ${SOURCE_PATH})
        message(FATAL_ERROR "HDL source file not found: ${SOURCE_PATH}")
    endif()

    # Register module in global list
    get_property(MODULES GLOBAL PROPERTY HDL_MODULES)
    list(APPEND MODULES ${MODULE_NAME})
    list(REMOVE_DUPLICATES MODULES)
    set_property(GLOBAL PROPERTY HDL_MODULES ${MODULES})

    # Store source file path
    set_property(GLOBAL PROPERTY HDL_MODULE_${MODULE_NAME}_SOURCE ${SOURCE_PATH})

    # Store source directory
    get_filename_component(SOURCE_DIR ${SOURCE_PATH} DIRECTORY)
    set_property(GLOBAL PROPERTY HDL_MODULE_${MODULE_NAME}_SOURCE_DIR ${SOURCE_DIR})

    # Store dependencies
    if(ARG_DEPENDS)
        set_property(GLOBAL PROPERTY HDL_MODULE_${MODULE_NAME}_DEPS ${ARG_DEPENDS})
    else()
        set_property(GLOBAL PROPERTY HDL_MODULE_${MODULE_NAME}_DEPS "")
    endif()

    # Log registration
    message(STATUS "Registered HDL module: ${MODULE_NAME}")
    if(ARG_DEPENDS)
        message(STATUS "  Dependencies: ${ARG_DEPENDS}")
    endif()
endfunction()

#------------------------------------------------------------------------------
# get_hdl_module_source(<module_name> <output_var>)
#
# Get the source file path for a registered HDL module.
#
#------------------------------------------------------------------------------
function(get_hdl_module_source MODULE_NAME OUTPUT_VAR)
    get_property(SOURCE GLOBAL PROPERTY HDL_MODULE_${MODULE_NAME}_SOURCE)
    if(NOT SOURCE)
        message(FATAL_ERROR "HDL module not found: ${MODULE_NAME}")
    endif()
    set(${OUTPUT_VAR} ${SOURCE} PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# get_hdl_module_deps(<module_name> <output_var>)
#
# Get the direct dependencies of a registered HDL module.
#
#------------------------------------------------------------------------------
function(get_hdl_module_deps MODULE_NAME OUTPUT_VAR)
    get_property(DEPS GLOBAL PROPERTY HDL_MODULE_${MODULE_NAME}_DEPS)
    set(${OUTPUT_VAR} ${DEPS} PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# get_hdl_module_all_deps(<module_name> <output_var>)
#
# Get all dependencies (recursive) of a registered HDL module.
# Returns dependencies in topological order (dependencies first).
#
#------------------------------------------------------------------------------
function(get_hdl_module_all_deps MODULE_NAME OUTPUT_VAR)
    set(ALL_DEPS "")
    set(TO_PROCESS ${MODULE_NAME})
    set(PROCESSED "")

    while(TO_PROCESS)
        # Pop first item
        list(GET TO_PROCESS 0 CURRENT)
        list(REMOVE_AT TO_PROCESS 0)

        # Skip if already processed
        list(FIND PROCESSED ${CURRENT} IDX)
        if(NOT IDX EQUAL -1)
            continue()
        endif()
        list(APPEND PROCESSED ${CURRENT})

        # Get direct dependencies
        get_property(DEPS GLOBAL PROPERTY HDL_MODULE_${CURRENT}_DEPS)

        # Add dependencies to process queue and result
        foreach(DEP ${DEPS})
            list(FIND ALL_DEPS ${DEP} IDX)
            if(IDX EQUAL -1)
                list(APPEND ALL_DEPS ${DEP})
                list(APPEND TO_PROCESS ${DEP})
            endif()
        endforeach()
    endwhile()

    set(${OUTPUT_VAR} ${ALL_DEPS} PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# get_hdl_module_all_sources(<module_name> <output_var>)
#
# Get all source files needed to compile a module (including dependencies).
# Returns sources in dependency order (dependencies first, then module).
#
#------------------------------------------------------------------------------
function(get_hdl_module_all_sources MODULE_NAME OUTPUT_VAR)
    # Get all dependencies
    get_hdl_module_all_deps(${MODULE_NAME} ALL_DEPS)

    # Collect source files
    set(ALL_SOURCES "")

    # Add dependency sources first
    foreach(DEP ${ALL_DEPS})
        get_property(SOURCE GLOBAL PROPERTY HDL_MODULE_${DEP}_SOURCE)
        if(SOURCE)
            list(APPEND ALL_SOURCES ${SOURCE})
        endif()
    endforeach()

    # Add module source last
    get_hdl_module_source(${MODULE_NAME} MODULE_SOURCE)
    list(APPEND ALL_SOURCES ${MODULE_SOURCE})

    # Remove duplicates while preserving order
    list(REMOVE_DUPLICATES ALL_SOURCES)

    set(${OUTPUT_VAR} ${ALL_SOURCES} PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# print_hdl_modules()
#
# Print all registered HDL modules and their dependencies (for debugging).
#
#------------------------------------------------------------------------------
function(print_hdl_modules)
    get_property(MODULES GLOBAL PROPERTY HDL_MODULES)

    message(STATUS "")
    message(STATUS "=== Registered HDL Modules ===")
    foreach(MODULE ${MODULES})
        get_property(SOURCE GLOBAL PROPERTY HDL_MODULE_${MODULE}_SOURCE)
        get_property(DEPS GLOBAL PROPERTY HDL_MODULE_${MODULE}_DEPS)

        message(STATUS "Module: ${MODULE}")
        message(STATUS "  Source: ${SOURCE}")
        if(DEPS)
            message(STATUS "  Dependencies: ${DEPS}")
        endif()
    endforeach()
    message(STATUS "==============================")
    message(STATUS "")
endfunction()
