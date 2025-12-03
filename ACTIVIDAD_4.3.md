Generador de Código FORK/JOIN para Grafos de Precedencia
Introducción al Problema
En programación concurrente, el desafío principal es determinar qué tareas pueden ejecutarse simultáneamente y cuáles deben esperar. Este sistema automatiza ese análisis: recibe un archivo con dependencias entre tareas y genera automáticamente código FORK/JOIN que ejecuta todo en paralelo de forma óptima y correcta.
Arquitectura del Sistema
Representación del Grafo
El núcleo usa un grafo dirigido acíclico (DAG) donde cada vértice es una tarea y cada arista indica "esta tarea debe ejecutarse antes que aquella". Usamos listas de adyacencia en lugar de matrices porque son más eficientes en memoria: O(V + E) versus O(V²).
javaprivate final Map<String, Vertice> vertices = new LinkedHashMap<>();
private final Map<Vertice, LinkedHashSet<Vertice>> adj = new LinkedHashMap<>();
El uso de LinkedHashMap mantiene el orden de inserción, garantizando resultados predecibles. Cada vértice mantiene su grado interno (dependencias pendientes) y grado externo (tareas que dependen de él).
Algoritmo de Kahn: Ordenamiento Topológico
Este algoritmo es el corazón del sistema. Produce una lista ordenada donde ninguna tarea aparece antes de sus prerequisitos.
Funcionamiento
javaprivate List<Vertice> ordenTopologico(boolean ascendente) {
    // 1. Copiar grados internos
    Map<Vertice, Integer> gradosIn = new HashMap<>();
    
    // 2. Cola de prioridad (S1 < S2 < S3...)
    PriorityQueue<Vertice> cola = new PriorityQueue<>(...);
    
    // 3. Agregar nodos sin dependencias (grado interno = 0)
    for (Vertice v : vertices.values()) {
        if (gradosIn.get(v) == 0) cola.add(v);
    }
La cola de prioridad ordena por número de etiqueta para resultados determinísticos. Iniciamos con todos los nodos "listos" (sin dependencias).
java    // 4. Procesar nodos y actualizar vecinos
    while (!cola.isEmpty()) {
        Vertice actual = cola.poll();
        resultado.add(actual);
        
        for (Vertice vecino : adj.get(actual)) {
            int nuevoGrado = gradosIn.get(vecino) - 1;
            gradosIn.put(vecino, nuevoGrado);
            if (nuevoGrado == 0) cola.add(vecino);  // Está listo
        }
    }
    
    // 5. Si no procesamos todos, hay ciclo
    return (resultado.size() == vertices.size()) ? resultado : null;
}
Complejidad: O(V + E) - óptimo.
Invariante clave: Un nodo entra a la cola solo cuando todas sus dependencias han sido procesadas.
Cálculo de Niveles
Los niveles identifican qué puede ejecutarse en paralelo. Todos los nodos en el mismo nivel pueden ejecutarse simultáneamente.
javaprivate Map<Vertice, Integer> calcularNiveles() {
    List<Vertice> topo = ordenTopologicoMenor();
    Map<Vertice, Integer> nivel = new HashMap<>();
    
    // Inicializar todos en nivel 0
    for (Vertice v : vertices.values()) nivel.put(v, 0);
    
    // Propagar niveles
    for (Vertice v : topo) {
        int nv = nivel.get(v);
        for (Vertice vecino : adj.get(v)) {
            if (nv + 1 > nivel.get(vecino)) {
                nivel.put(vecino, nv + 1);
            }
        }
    }
    return nivel;
}
El nivel de un nodo es la distancia máxima desde cualquier raíz. Tomamos el máximo porque un nodo puede tener múltiples predecesores y debe esperar al más lejano.
Generación de Código FORK/JOIN
Semántica Básica

FORK etiqueta: Crea un hilo que salta a esa etiqueta
JOIN contador: Decrementa contador; si llega a 0, continúa; si no, el hilo termina
contador = N: Inicializa sincronización para N hilos

Implementación
javapublic void imprimirCodigoForkJoin() {
    Map<Vertice, Integer> nivel = calcularNiveles();
    
    // Agrupar por nivel
    Map<Integer, List<Vertice>> porNivel = new LinkedHashMap<>();
    // ... agrupar nodos ...
    
    for (int l = 0; l <= maxNivel; l++) {
        List<Vertice> nodos = porNivel.get(l);
        nodos.sort(comparadorNumerico);
Caso 1: Un solo nodo (ejecución secuencial):
java        if (nodos.size() == 1) {
            System.out.println("L" + contador + ": " + nodo + ";");
            contador++;
        }
Caso 2: Múltiples nodos (ejecución paralela):
java        } else {
            int k = nodos.size();
            System.out.println("cont" + l + " = " + k + ";");
            
            // FORK para K-1 hilos (el principal ejecuta la primera tarea)
            for (int i = 1; i < k; i++) {
                System.out.println("FORK L" + (contador + i) + ";");
            }
            
            // Hilo principal
            System.out.println("L" + contador + ": " + nodos.get(0) + ";");
            System.out.println("JOIN cont" + l + ";");
            
            // Hilos paralelos
            for (int i = 1; i < k; i++) {
                System.out.println("L" + (contador + i) + ": " + nodos.get(i) + ";");
                System.out.println("JOIN cont" + l + ";");
            }
        }
    }
}
```

### Ejemplo: Grafo Diamante

**Entrada:**
```
    S1
   /  \
  S2   S3
   \  /
    S4
```

**Código generado:**
```
L1: S1;

// Nivel 1 (paralelo: 2 sentencias)
cont1 = 2;
FORK L3;
L2: S2;
JOIN cont1;
L3: S3;
JOIN cont1;

// Nivel 2
L4: S4;
Interfaz Gráfica
Visualización del Grafo
javaprivate void calcularPosiciones() {
    Map<Vertice, Integer> niveles = calcularNiveles();
    
    // Posición X: proporcional al nivel
    int x = MARGEN + (nivel * anchoDisponible / maxNivel);
    
    // Posición Y: distribuir uniformemente nodos del mismo nivel
    int espacioVertical = altoDisponible / nodosNivel.size();
    int y = MARGEN + espacioVertical * indice;
}
Los nodos se organizan por niveles horizontalmente. Nodos en la misma columna vertical = ejecución paralela.
Dibujo de Flechas
javaprivate void dibujarFlecha(Graphics2D g2d, int x1, int y1, int x2, int y2) {
    double angulo = Math.atan2(y2 - y1, x2 - x1);
    
    // Calcular puntos de la punta usando trigonometría
    int x3 = x2 - (int)(longitudFlecha * Math.cos(angulo - 25°));
    int y3 = y2 - (int)(longitudFlecha * Math.sin(angulo - 25°));
    // ... punto 4 similar ...
    
    g2d.drawLine(x2, y2, x3, y3);
    g2d.drawLine(x2, y2, x4, y4);
}
Lectura de Archivos
javapublic static Grafo desdeArchivoMatriz(String archivo) throws IOException {
    // Leer matriz de adyacencia
    // matriz[i][j] = 1 significa Si -> Sj
    
    Grafo g = new Grafo(true);
    
    // Crear vértices S1..Sn
    for (int i = 1; i <= n; i++) {
        g.agregarVertice(new Vertice("S" + i));
    }
    
    // Agregar arcos
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            if (matriz[i][j] == 1) {
                g.agregarLado(Si, Sj);
            }
        }
    }
    return g;
}
Ventajas del Sistema

Corrección Garantizada: El algoritmo respeta todas las dependencias por construcción
Máximo Paralelismo: Identifica todas las oportunidades de ejecución concurrente
Eficiencia: O(V + E) en todos los pasos - escalable a grafos grandes
Determinismo: Resultados predecibles entre ejecuciones
Detección de Errores: Identifica ciclos (dependencias imposibles) automáticamente

Aplicaciones Reales

Compiladores: Reordenamiento de instrucciones para procesadores multi-núcleo
Sistemas de Build: Make, Gradle - qué archivos compilar en paralelo
Gestión de Proyectos: Método PERT/CPM para planificación óptima
Pipelines de Datos: Apache Airflow, Spark - distribución de tareas
CI/CD: Ejecución paralela de tests y deployment

Conclusión
Este sistema demuestra cómo algoritmos clásicos de grafos (ordenamiento topológico, cálculo de niveles) resuelven problemas prácticos de programación concurrente. La implementación combina eficiencia algorítmica (O(V + E)), corrección formal (invariantes claras), y usabilidad (interfaz gráfica intuitiva) en una herramienta que automatiza completamente la generación de código paralelo a partir de especificaciones de dependencias.Claude puede cometer errores. Verifique las respuestas. Sonnet 4.5
