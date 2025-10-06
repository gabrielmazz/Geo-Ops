package com.geo.api.routing;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

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

    public Optional<RouteResponse> route(Coordinate origin, Coordinate destination) {
        try {
            URI requestUri = buildRouteUri(origin, destination);
            OsrmResponse response = restTemplate.getForObject(requestUri, OsrmResponse.class);

            if (response == null || response.routes == null || response.routes.isEmpty()) {
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

            return Optional.of(new RouteResponse(
                    List.of("origem", "destino"),
                    coordinates,
                    distanceKm
            ));
        } catch (RestClientException ex) {
            LOGGER.error("Falha ao consultar OSRM", ex);
            return Optional.empty();
        }
    }

    private URI buildRouteUri(Coordinate origin, Coordinate destination) {
        String coordinateSegment = String.format(Locale.US, "%f,%f;%f,%f",
                origin.lon(), origin.lat(),
                destination.lon(), destination.lat());

        return UriComponentsBuilder.fromHttpUrl(baseUrl)
                .pathSegment("route", "v1", "driving", coordinateSegment)
                .queryParam("overview", "full")
                .queryParam("geometries", "geojson")
                .build(true)
                .toUri();
    }

    private record OsrmResponse(List<OsrmRoute> routes) {
    }

    private record OsrmRoute(double distance, double duration, OsrmGeometry geometry) {
    }

    private record OsrmGeometry(List<List<Double>> coordinates) {
    }
}
