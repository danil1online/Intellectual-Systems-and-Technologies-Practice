"""
Глобальная конфигурация IPython kernel для загрузки %%ask_mentor в каждом ядре.
"""
c = get_config()
mentor_code = open("/app/startup/00_mentor.py").read()
c.InteractiveShellApp.exec_lines = [mentor_code]
