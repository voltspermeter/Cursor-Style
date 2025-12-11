#------------------------------------------------------------------------------
#
# IcarusVerilog.cmake - CMake functions for Icarus Verilog simulation
#
# This module provides functions to compile and simulate HDL designs using
# Icarus Verilog (iverilog/vvp).
#
#------------------------------------------------------------------------------

# Find Icarus Verilog executables
find_program(IVERILOG_EXECUTABLE iverilog
    HINTS ENV PATH
    DOC "Icarus Verilog compiler"
)

find_program(VVP_EXECUTABLE vvp
    HINTS ENV PATH
    DOC "Icarus Verilog simulation runtime"
)

# Check if Icarus Verilog is available
if(IVERILOG_EXECUTABLE)
    message(STATUS "Found iverilog: ${IVERILOG_EXECUTABLE}")
    execute_process(
        COMMAND ${IVERILOG_EXECUTABLE} -V
        OUTPUT_VARIABLE IVERILOG_VERSION_OUTPUT
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    string(REGEX MATCH "Icarus Verilog version [0-9]+\\.[0-9]+" IVERILOG_VERSION "${IVERILOG_VERSION_OUTPUT}")
    if(IVERILOG_VERSION)
        message(STATUS "  Version: ${IVERILOG_VERSION}")
    endif()
else()
    message(WARNING "iverilog not found - HDL simulation targets will not be available")
endif()

if(VVP_EXECUTABLE)
    message(STATUS "Found vvp: ${VVP_EXECUTABLE}")
else()
    message(WARNING "vvp not found - HDL simulation targets will not be available")
endif()

# Default compiler flags
set(IVERILOG_FLAGS "-g2012" CACHE STRING "Default Icarus Verilog compiler flags")
set(IVERILOG_INCLUDE_DIRS "" CACHE STRING "Additional include directories for iverilog")

#------------------------------------------------------------------------------
# add_iverilog_library(<name> <sources...>)
#
# Create a target for compiling HDL sources with Icarus Verilog.
# This creates a .vvp file that can be executed with vvp.
#
# Arguments:
#   name     - Target name (also used for output .vvp file)
#   sources  - List of Verilog/SystemVerilog source files
#
#------------------------------------------------------------------------------
function(add_iverilog_library TARGET_NAME)
    if(NOT IVERILOG_EXECUTABLE)
        message(WARNING "iverilog not found, skipping target: ${TARGET_NAME}")
        return()
    endif()

    set(SOURCES ${ARGN})

    # Output file
    set(OUTPUT_FILE ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}.vvp)

    # Build include flags
    set(INCLUDE_FLAGS "")
    foreach(INC_DIR ${IVERILOG_INCLUDE_DIRS})
        list(APPEND INCLUDE_FLAGS "-I${INC_DIR}")
    endforeach()

    # Add custom command to compile
    add_custom_command(
        OUTPUT ${OUTPUT_FILE}
        COMMAND ${IVERILOG_EXECUTABLE}
            ${IVERILOG_FLAGS}
            ${INCLUDE_FLAGS}
            -o ${OUTPUT_FILE}
            ${SOURCES}
        DEPENDS ${SOURCES}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT "Compiling ${TARGET_NAME} with iverilog"
        VERBATIM
    )

    # Add custom target
    add_custom_target(${TARGET_NAME}
        DEPENDS ${OUTPUT_FILE}
    )

    # Store output file path as target property
    set_target_properties(${TARGET_NAME} PROPERTIES
        VVP_FILE ${OUTPUT_FILE}
        SOURCES "${SOURCES}"
    )
endfunction()

#------------------------------------------------------------------------------
# add_hdl_module_target(<module_name>)
#
# Create an Icarus Verilog compile target for a registered HDL module.
# Automatically includes all dependencies.
#
# Arguments:
#   module_name - Name of a module registered with add_hdl_source
#
#------------------------------------------------------------------------------
function(add_hdl_module_target MODULE_NAME)
    if(NOT IVERILOG_EXECUTABLE)
        message(WARNING "iverilog not found, skipping target: ${MODULE_NAME}")
        return()
    endif()

    # Get all source files including dependencies
    get_hdl_module_all_sources(${MODULE_NAME} ALL_SOURCES)

    if(NOT ALL_SOURCES)
        message(WARNING "No sources found for module: ${MODULE_NAME}")
        return()
    endif()

    # Create target name
    set(TARGET_NAME "hdl_${MODULE_NAME}")

    # Output file
    set(OUTPUT_FILE ${CMAKE_CURRENT_BINARY_DIR}/${MODULE_NAME}.vvp)

    # Build include flags
    set(INCLUDE_FLAGS "")
    foreach(INC_DIR ${IVERILOG_INCLUDE_DIRS})
        list(APPEND INCLUDE_FLAGS "-I${INC_DIR}")
    endforeach()

    # Add custom command to compile
    add_custom_command(
        OUTPUT ${OUTPUT_FILE}
        COMMAND ${IVERILOG_EXECUTABLE}
            ${IVERILOG_FLAGS}
            ${INCLUDE_FLAGS}
            -o ${OUTPUT_FILE}
            ${ALL_SOURCES}
        DEPENDS ${ALL_SOURCES}
        COMMENT "Compiling HDL module: ${MODULE_NAME}"
        VERBATIM
    )

    # Add custom target
    add_custom_target(${TARGET_NAME}
        DEPENDS ${OUTPUT_FILE}
    )

    # Store properties
    set_target_properties(${TARGET_NAME} PROPERTIES
        VVP_FILE ${OUTPUT_FILE}
        HDL_MODULE ${MODULE_NAME}
        SOURCES "${ALL_SOURCES}"
    )

    message(STATUS "Created HDL target: ${TARGET_NAME}")
endfunction()

#------------------------------------------------------------------------------
# add_iverilog_simulation(<name> <top_module> <sources...>
#                         [PLUS_ARGS <args...>]
#                         [VVP_ARGS <args...>]
#                         [TIMEOUT <seconds>])
#
# Create targets for compiling and running a simulation.
#
# Creates two targets:
#   <name>_compile - Compiles the design
#   <name>_run     - Runs the simulation
#   <name>         - Alias for run
#
# Arguments:
#   name        - Base target name
#   top_module  - Top-level module name
#   sources     - List of source files
#   PLUS_ARGS   - Plus arguments to pass to simulation (+arg=value)
#   VVP_ARGS    - Arguments to pass to vvp
#   TIMEOUT     - Simulation timeout in seconds
#
#------------------------------------------------------------------------------
function(add_iverilog_simulation TARGET_NAME TOP_MODULE)
    if(NOT IVERILOG_EXECUTABLE OR NOT VVP_EXECUTABLE)
        message(WARNING "Icarus Verilog not found, skipping simulation: ${TARGET_NAME}")
        return()
    endif()

    # Parse arguments
    cmake_parse_arguments(ARG "" "TIMEOUT" "PLUS_ARGS;VVP_ARGS" ${ARGN})
    set(SOURCES ${ARG_UNPARSED_ARGUMENTS})

    # Output files
    set(VVP_FILE ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}.vvp)
    set(VCD_FILE ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}.vcd)
    set(LOG_FILE ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}.log)

    # Build include flags
    set(INCLUDE_FLAGS "")
    foreach(INC_DIR ${IVERILOG_INCLUDE_DIRS})
        list(APPEND INCLUDE_FLAGS "-I${INC_DIR}")
    endforeach()

    # Compile command
    add_custom_command(
        OUTPUT ${VVP_FILE}
        COMMAND ${IVERILOG_EXECUTABLE}
            ${IVERILOG_FLAGS}
            ${INCLUDE_FLAGS}
            -s ${TOP_MODULE}
            -o ${VVP_FILE}
            ${SOURCES}
        DEPENDS ${SOURCES}
        COMMENT "Compiling simulation: ${TARGET_NAME}"
        VERBATIM
    )

    # Compile target
    add_custom_target(${TARGET_NAME}_compile
        DEPENDS ${VVP_FILE}
    )

    # Build vvp command
    set(VVP_CMD ${VVP_EXECUTABLE})
    if(ARG_VVP_ARGS)
        list(APPEND VVP_CMD ${ARG_VVP_ARGS})
    endif()
    list(APPEND VVP_CMD ${VVP_FILE})
    if(ARG_PLUS_ARGS)
        list(APPEND VVP_CMD ${ARG_PLUS_ARGS})
    endif()

    # Run target (always runs, doesn't track output)
    add_custom_target(${TARGET_NAME}_run
        COMMAND ${VVP_CMD}
        DEPENDS ${VVP_FILE}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Running simulation: ${TARGET_NAME}"
        VERBATIM
    )

    # Alias target
    add_custom_target(${TARGET_NAME}
        DEPENDS ${TARGET_NAME}_run
    )

    # Store properties
    set_target_properties(${TARGET_NAME}_compile PROPERTIES
        VVP_FILE ${VVP_FILE}
        TOP_MODULE ${TOP_MODULE}
        SOURCES "${SOURCES}"
    )

    message(STATUS "Created simulation target: ${TARGET_NAME}")
endfunction()

#------------------------------------------------------------------------------
# create_all_hdl_targets()
#
# Create Icarus Verilog compile targets for all registered HDL modules.
#
#------------------------------------------------------------------------------
function(create_all_hdl_targets)
    get_property(MODULES GLOBAL PROPERTY HDL_MODULES)

    foreach(MODULE ${MODULES})
        add_hdl_module_target(${MODULE})
    endforeach()
endfunction()
