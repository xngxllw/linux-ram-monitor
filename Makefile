.PHONY: up start stop down status logs check

up:
	podman-compose up -d
	@echo "Stack desplegado -> http://127.0.0.1:3000 (admin / admin)"

start:
	podman-compose start
	@echo "Monitoreo iniciado -> http://127.0.0.1:3000"

stop:
	podman-compose stop
	@echo "Monitoreo pausado. Los registros siguen guardados en disco."

down:
	podman-compose down

status:
	podman ps -a --filter name=ram-

logs:
	podman-compose logs -f

check:
	@curl -s http://127.0.0.1:8428/api/v1/targets | grep -o '"health":"up"' && echo "Targets OK" || echo "Targets sin conexión"
