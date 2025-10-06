package com.geo.api.routing;

import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class RouteService {

    private final OsrmRoutingService osrmRoutingService;

    public RouteService(OsrmRoutingService osrmRoutingService) {
        this.osrmRoutingService = osrmRoutingService;
    }

    public RouteResponse calculateRoute(Coordinate origin, Coordinate destination) {
        System.out.printf("[RouteService] Requisição recebida: origem=%s destino=%s%n", origin, destination);

        return osrmRoutingService.route(origin, destination)
                .map(route -> {
                    System.out.printf("[RouteService] OSRM retornou rota com %.2f km e %d pontos.%n",
                            route.totalCost(), route.coordinates().size());
                    return route;
                })
                .orElseGet(() -> {
                    System.out.println("[RouteService] OSRM não retornou rota.");
                    return new RouteResponse(List.<String>of(), List.<Coordinate>of(), Double.NaN);
                });
    }
}
