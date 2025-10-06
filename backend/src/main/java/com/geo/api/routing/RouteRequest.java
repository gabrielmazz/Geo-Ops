package com.geo.api.routing;

import java.util.List;

public record RouteRequest(List<List<Double>> points) {

    public Coordinate origin() {
        return toCoordinate(0);
    }

    public Coordinate destination() {
        int lastIndex = points.size() - 1;
        return toCoordinate(lastIndex);
    }

    private Coordinate toCoordinate(int index) {
        if (points == null || points.isEmpty()) {
            throw new IllegalArgumentException("A lista de pontos nao pode ser vazia");
        }
        if (index < 0 || index >= points.size()) {
            throw new IllegalArgumentException("Indice de ponto invalido: " + index);
        }
        List<Double> pair = points.get(index);
        if (pair == null || pair.size() != 2) {
            throw new IllegalArgumentException("Cada ponto deve conter lat e lon");
        }
        return new Coordinate(pair.get(0), pair.get(1));
    }
}
