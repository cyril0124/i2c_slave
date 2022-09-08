@REM 控制台不显示命令本身
@echo off

set MODULE_NAME=test_tb
set WORKSPACE_DIR=%~dp0
set TB_DIR=%WORKSPACE_DIR%\tb

set YEAR=%date:~0,4%
set MONTH=%date:~5,-6%
set DAY=%date:~8,-3%

set HH=%time:~0,2%
set MM=%time:~3,2%
set SS=%time:~6,2%

@REM 获取编译时间
set BUILD_TIME_TEMP=%YEAR%%MONTH%%DAY%_%HH%%MM%%SS%
@REM 如果 hour 小于10，会有空格，下面这句代码可以去除字符串中的空格，并用0替代
set BUILD_TIME=%BUILD_TIME_TEMP: =0%

@REM 备份上次编译的文件
md build
md .\build\history
del %WORKSPACE_DIR%\build\history\*.out
del %WORKSPACE_DIR%\build\history\*.vcd
del %WORKSPACE_DIR%\build\history\*.log
copy %WORKSPACE_DIR%\build\*.out .\build\history
copy %WORKSPACE_DIR%\build\*.vcd .\build\history
copy %WORKSPACE_DIR%\build\*.log .\build\history
del %WORKSPACE_DIR%\build\*.out
del %WORKSPACE_DIR%\build\*.vcd
del %WORKSPACE_DIR%\build\*.log

@REM 生成iverilog编译文件
@REM -s (topmodule) (topmodule file) 用于指定顶层模块
@REM -c (filelist) 用于指定编译文件
@REM iverilog -s %MODULE_NAME% %MODULE_NAME%.v
iverilog -o %MODULE_NAME%_%BUILD_TIME%.out -c%WORKSPACE_DIR%\filelist.icarus

@REM vvp生成仿真文件
@REM -n (source iverilog build file) 表示非交互模式启用vvp 
@REM -l (log file) 表示生成log到文件中
vvp  -l vvp_sim_%BUILD_TIME%.log -n %MODULE_NAME%_%BUILD_TIME%.out

rename *.vcd %MODULE_NAME%_%BUILD_TIME%.vcd
move %MODULE_NAME%_%BUILD_TIME%.out %WORKSPACE_DIR%\build
move %MODULE_NAME%_%BUILD_TIME%.vcd %WORKSPACE_DIR%\build
move vvp_sim_%BUILD_TIME%.log %WORKSPACE_DIR%\build

@REM gtkwave打开波形
gtkwave %WORKSPACE_DIR%\build\%MODULE_NAME%_%BUILD_TIME%.vcd %WORKSPACE_DIR%\build\*.gtkw

