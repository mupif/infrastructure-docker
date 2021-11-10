default:
	docker-compose -f container.yml up --build --remove-orphans
refresh:
	docker-compose -f container.yml build --no-cache
join: 
	docker exec -ti mupif-musicode_central_1 /bin/bash
