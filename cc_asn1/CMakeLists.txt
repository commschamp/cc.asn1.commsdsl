include (GNUInstallDirs)
install(
    DIRECTORY dsl dsl_src DESTINATION ${CMAKE_INSTALL_PREFIX}/src/${PROJECT_NAME}
)
