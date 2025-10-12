package com.geo.api.routing;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

@Service
public class OsrmRoutingService {

    private static final Logger LOGGER = LoggerFactory.getLogger(OsrmRoutingService.class);

    private final RestTemplate restTemplate;
    private final String baseUrl;

    public OsrmRoutingService(RestTemplate restTemplate,
                              @Value("${routing.osrm.base-url:https://router.project-osrm.org}") String baseUrl) {
        this.restTemplate = restTemplate;
        this.baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
    }

    public Optional<RouteResponse> route(List<Coordinate> anchors, boolean allowApproximation) {
        if (anchors == null || anchors.size() < 2) {
            throw new IllegalArgumentException("Informe pelo menos origem e destino para calcular a rota.");
        }

        List<Coordinate> effectiveAnchors = anchors;
        if (allowApproximation) {
            effectiveAnchors = snapAnchors(anchors);
        }

        boolean approximated = allowApproximation && !effectiveAnchors.equals(anchors);

        Optional<RouteResponse> directResult = attemptRoute(effectiveAnchors, anchors.size());
        if (directResult.isPresent()) {
            return directResult;
        }

        if (approximated) {
            LOGGER.warn("Tentativa com pontos aproximados falhou. Tentando novamente com os pontos originais.");
            return attemptRoute(anchors, anchors.size());
        }

        return Optional.empty();
    }

    private Optional<RouteResponse> attemptRoute(List<Coordinate> anchors, int originalCount) {
        try {
            URI requestUri = buildRouteUri(anchors);
            OsrmResponse response = restTemplate.getForObject(requestUri, OsrmResponse.class);

            if (response == null || response.routes == null || response.routes.isEmpty()) {
                Coordinate origin = anchors.get(0);
                Coordinate destination = anchors.get(anchors.size() - 1);
                LOGGER.warn("OSRM não retornou rotas para {} -> {}", origin, destination);
                return Optional.empty();
            }

            OsrmRoute osrmRoute = response.routes.getFirst();
            if (osrmRoute.geometry == null || osrmRoute.geometry.coordinates == null) {
                LOGGER.warn("OSRM respondeu sem geometria válida");
                return Optional.empty();
            }

            List<Coordinate> coordinates = osrmRoute.geometry.coordinates.stream()
                    .filter(pair -> pair != null && pair.size() >= 2)
                    .map(pair -> new Coordinate(pair.get(1), pair.get(0)))
                    .toList();

            double distanceKm = osrmRoute.distance / 1000.0;
            List<String> nodeLabels = buildNodeLabels(originalCount);

            return Optional.of(new RouteResponse(
                    nodeLabels,
                    coordinates,
                    distanceKm
            ));
        } catch (RestClientException ex) {
            LOGGER.error("Falha ao consultar OSRM", ex);
            return Optional.empty();
        }
    }

    private List<Coordinate> snapAnchors(List<Coordinate> anchors) {
        List<Coordinate> adjusted = new ArrayList<>(anchors.size());

        for (int index = 0; index < anchors.size(); index++) {
            Coordinate anchor = anchors.get(index);
            Optional<Coordinate> snapped = snapToRoad(anchor);
            if (snapped.isPresent()) {
                Coordinate candidate = snapped.get();
                if (!candidate.equals(anchor)) {
                    LOGGER.info("Ponto {} aproximado de {} para {}", index, anchor, candidate);
                }
                adjusted.add(candidate);
            } else {
                adjusted.add(anchor);
            }
        }

        return adjusted;
    }

    private Optional<Coordinate> snapToRoad(Coordinate anchor) {
        try {
            URI requestUri = buildNearestUri(anchor);
            OsrmNearestResponse response = restTemplate.getForObject(requestUri, OsrmNearestResponse.class);
            if (response == null || response.waypoints == null || response.waypoints.isEmpty()) {
                return Optional.empty();
            }

            OsrmNearestWaypoint waypoint = response.waypoints.getFirst();
            if (waypoint == null || waypoint.location == null || waypoint.location.size() < 2) {
                return Optional.empty();
            }

            double lon = waypoint.location.get(0);
            double lat = waypoint.location.get(1);
            return Optional.of(new Coordinate(lat, lon));
        } catch (RestClientException ex) {
            LOGGER.debug("Falha ao aproximar ponto {}: {}", anchor, ex.getMessage());
            return Optional.empty();
        }
    }

    private URI buildRouteUri(List<Coordinate> anchors) {
        String coordinateSegment = anchors.stream()
                .map(point -> String.format(Locale.US, "%f,%f", point.lon(), point.lat()))
                .collect(Collectors.joining(";"));

        return UriComponentsBuilder.fromHttpUrl(baseUrl)
                .pathSegment("route", "v1", "driving", coordinateSegment)
                .queryParam("overview", "full")
                .queryParam("geometries", "geojson")
                .build(true)
                .toUri();
    }

    private URI buildNearestUri(Coordinate anchor) {
        String coordinate = String.format(Locale.US, "%f,%f", anchor.lon(), anchor.lat());
        return UriComponentsBuilder.fromHttpUrl(baseUrl)
                .pathSegment("nearest", "v1", "driving", coordinate)
                .queryParam("number", 1)
                .build(true)
                .toUri();
    }

    private List<String> buildNodeLabels(int count) {
        if (count <= 0) {
            return List.of();
        }

        return IntStream.range(0, count)
                .mapToObj(index -> {
                    if (index == 0) {
                        return "Origem";
                    }
                    if (index == count - 1) {
                        return "Destino";
                    }
                    return "Ponto " + index;
                })
                .toList();
    }

    private record OsrmResponse(List<OsrmRoute> routes) {
    }

    private record OsrmRoute(double distance, double duration, OsrmGeometry geometry) {
    }

    private record OsrmGeometry(List<List<Double>> coordinates) {
    }

    private record OsrmNearestResponse(List<OsrmNearestWaypoint> waypoints) {
    }

    private record OsrmNearestWaypoint(List<Double> location) {
    }
}
