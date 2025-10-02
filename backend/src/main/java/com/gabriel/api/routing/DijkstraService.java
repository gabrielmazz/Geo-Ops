package com.gabriel.api.routing;

import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class DijkstraService {

    public record Edge(String targetId, double cost) {
    }

    public record ShortestPathResult(List<String> path, double totalCost) {
    }

    public ShortestPathResult shortestPath(
            String startId,
            String targetId,
            Map<String, List<Edge>> graph
    ) {
        Set<String> nodes = new HashSet<>(graph.keySet());
        for (List<Edge> edges : graph.values()) {
            for (Edge edge : edges) {
                nodes.add(edge.targetId());
            }
        }

        if (!nodes.contains(startId) || !nodes.contains(targetId)) {
            throw new IllegalArgumentException("Nos de origem ou destino inexistentes no grafo");
        }

        Map<String, Double> dist = new HashMap<>();
        Map<String, String> previous = new HashMap<>();
        for (String node : nodes) {
            dist.put(node, Double.POSITIVE_INFINITY);
        }
        dist.put(startId, 0.0);

        PriorityQueue<String> queue = new PriorityQueue<>(Comparator.comparingDouble(dist::get));
        queue.add(startId);

        while (!queue.isEmpty()) {
            String current = queue.poll();
            if (current.equals(targetId)) {
                break;
            }

            for (Edge edge : graph.getOrDefault(current, List.of())) {
                double candidate = dist.get(current) + edge.cost();
                if (candidate < dist.get(edge.targetId())) {
                    dist.put(edge.targetId(), candidate);
                    previous.put(edge.targetId(), current);
                    queue.remove(edge.targetId());
                    queue.add(edge.targetId());
                }
            }
        }

        double costToTarget = dist.get(targetId);
        if (Double.isInfinite(costToTarget)) {
            return new ShortestPathResult(List.of(), costToTarget);
        }

        LinkedList<String> path = new LinkedList<>();
        String step = targetId;
        while (step != null) {
            path.addFirst(step);
            step = previous.get(step);
        }

        return new ShortestPathResult(List.copyOf(path), costToTarget);
    }
}
