include (GNUInstallDirs)
install(
    DIRECTORY dsl dsl_src DESTINATION ${CMAKE_INSTALL_FULL_DATADIR}/${PROJECT_NAME}
)
