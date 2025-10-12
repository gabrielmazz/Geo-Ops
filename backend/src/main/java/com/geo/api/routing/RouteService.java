package com.geo.api.routing;

import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Objects;

@Service
public class RouteService {

    private final OsrmRoutingService osrmRoutingService;

    public RouteService(OsrmRoutingService osrmRoutingService) {
        this.osrmRoutingService = osrmRoutingService;
    }

    public RouteResponse calculateRoute(List<Coordinate> anchors, boolean allowApproximation) {
        Objects.requireNonNull(anchors, "A lista de pontos não pode ser nula");

        if (anchors.size() < 2) {
            throw new IllegalArgumentException("É necessário informar pelo menos origem e destino.");
        }

        System.out.printf("[RouteService] Requisição recebida com %d pontos.%n", anchors.size());

        return osrmRoutingService.route(anchors, allowApproximation)
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
