package com.gabriel.api.routing;

import java.util.List;

public record RouteResponse(List<String> nodes, List<Coordinate> coordinates, double totalCost) {
}
