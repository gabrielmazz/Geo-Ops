package com.gabriel.api.routing;

import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class RouteService {

    private final DijkstraService dijkstraService;
    private final OsrmRoutingService osrmRoutingService;
    private final Map<String, GraphNode> nodeIndex;
    private final Map<String, List<DijkstraService.Edge>> graph;

    public RouteService(DijkstraService dijkstraService, OsrmRoutingService osrmRoutingService) {
        this.dijkstraService = dijkstraService;
        this.osrmRoutingService = osrmRoutingService;
        this.nodeIndex = new HashMap<>();
        this.graph = new HashMap<>();

        registerNode(new GraphNode("SP", new Coordinate(-23.5505, -46.6333))); // Sao Paulo
        registerNode(new GraphNode("RJ", new Coordinate(-22.9068, -43.1729))); // Rio de Janeiro
        registerNode(new GraphNode("BH", new Coordinate(-19.9167, -43.9345))); // Belo Horizonte
        registerNode(new GraphNode("BSB", new Coordinate(-15.793889, -47.882778))); // Brasilia
        registerNode(new GraphNode("SSA", new Coordinate(-12.9777, -38.5016))); // Salvador

        connectBidirectional("SP", "RJ");
        connectBidirectional("SP", "BH");
        connectBidirectional("BH", "RJ");
        connectBidirectional("BH", "BSB");
        connectBidirectional("RJ", "SSA");
        connectBidirectional("BH", "SSA");
        connectBidirectional("BSB", "SSA");
    }

    public RouteResponse calculateRoute(Coordinate origin, Coordinate destination) {
        System.out.printf("[RouteService] Requisição recebida: origem=%s destino=%s%n", origin, destination);

        RouteResponse osrmRoute = osrmRoutingService.route(origin, destination)
                .map(route -> {
                    System.out.printf("[RouteService] OSRM retornou rota com %.2f km e %d pontos.%n",
                            route.totalCost(), route.coordinates().size());
                    return route;
                })
                .orElse(null);

        if (osrmRoute != null) {
            return osrmRoute;
        }

        System.out.println("[RouteService] OSRM indisponível. Caindo para Dijkstra interno.");
        return calculateWithInternalGraph(origin, destination);
    }

    private RouteResponse calculateWithInternalGraph(Coordinate origin, Coordinate destination) {
        String originNode = nearestNodeId(origin);
        String destinationNode = nearestNodeId(destination);

        System.out.printf("[RouteService] Executando Dijkstra do nó %s até %s.%n", originNode, destinationNode);

        DijkstraService.ShortestPathResult result =
                dijkstraService.shortestPath(originNode, destinationNode, graph);

        List<String> pathNodes = result.path();
        System.out.printf("[RouteService] Dijkstra encontrou caminho com %d nós e custo %.2f km.%n",
                pathNodes.size(), result.totalCost());

        List<Coordinate> nodeCoordinates = pathNodes.stream()
                .map(nodeIndex::get)
                .filter(Objects::nonNull)
                .map(GraphNode::coordinate)
                .toList();

        List<Coordinate> routeCoordinates = new ArrayList<>();
        routeCoordinates.add(origin);
        routeCoordinates.addAll(nodeCoordinates);

        Coordinate last = routeCoordinates.get(routeCoordinates.size() - 1);
        if (!isSameCoordinate(last, destination)) {
            routeCoordinates.add(destination);
        }

        RouteResponse response = new RouteResponse(pathNodes, routeCoordinates, result.totalCost());
        System.out.printf("[RouteService] Resposta Dijkstra com %d pontos retornada.%n", routeCoordinates.size());
        return response;
    }

    private void registerNode(GraphNode node) {
        nodeIndex.put(node.id(), node);
        graph.putIfAbsent(node.id(), new ArrayList<>());
    }

    private void connectBidirectional(String fromId, String toId) {
        connect(fromId, toId);
        connect(toId, fromId);
    }

    private void connect(String fromId, String toId) {
        GraphNode from = nodeIndex.get(fromId);
        GraphNode to = nodeIndex.get(toId);
        if (from == null || to == null) {
            throw new IllegalArgumentException("Tentativa de conectar nos inexistentes");
        }
        double distanceKm = haversineKm(from.coordinate(), to.coordinate());
        graph.computeIfAbsent(fromId, key -> new ArrayList<>())
                .add(new DijkstraService.Edge(toId, distanceKm));
    }

    private String nearestNodeId(Coordinate coordinate) {
        return nodeIndex.values().stream()
                .min(Comparator.comparingDouble(node -> haversineKm(node.coordinate(), coordinate)))
                .map(GraphNode::id)
                .orElseThrow(() -> new IllegalStateException("Nenhum no cadastrado"));
    }

    private double haversineKm(Coordinate a, Coordinate b) {
        double earthRadiusKm = 6371.0;

        double lat1 = Math.toRadians(a.lat());
        double lon1 = Math.toRadians(a.lon());
        double lat2 = Math.toRadians(b.lat());
        double lon2 = Math.toRadians(b.lon());

        double dLat = lat2 - lat1;
        double dLon = lon2 - lon1;

        double hav = Math.pow(Math.sin(dLat / 2), 2)
                + Math.cos(lat1) * Math.cos(lat2) * Math.pow(Math.sin(dLon / 2), 2);
        double c = 2 * Math.atan2(Math.sqrt(hav), Math.sqrt(1 - hav));

        return earthRadiusKm * c;
    }

    private boolean isSameCoordinate(Coordinate a, Coordinate b) {
        double tolerance = 1e-6;
        return Math.abs(a.lat() - b.lat()) < tolerance && Math.abs(a.lon() - b.lon()) < tolerance;
    }
}
