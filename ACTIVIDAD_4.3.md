Generador de Código FORK/JOIN para Grafos de Precedencia
Introducción al Problema
En el ámbito de la programación concurrente y paralela, uno de los desafíos más importantes es determinar qué tareas pueden ejecutarse simultáneamente y cuáles deben esperar a que otras terminen primero. Imaginemos un proyecto de construcción: no podemos pintar las paredes antes de levantarlas, ni podemos instalar el techo antes de tener las columnas. Estas relaciones de dependencia entre tareas son exactamente lo que modelamos con un grafo de precedencia.
Este sistema que presento automatiza completamente el proceso de análisis de dependencias y genera código FORK/JOIN ejecutable. El usuario simplemente proporciona un archivo con las relaciones de precedencia (quién debe ir antes de quién), y el sistema produce el código paralelo optimizado que respeta todas las restricciones de orden.
Arquitectura del Sistema
Representación del Grafo (Grafo.java)
El corazón del sistema es la clase Grafo, que implementa un grafo dirigido acíclico (DAG - Directed Acyclic Graph). La elección de un DAG no es arbitraria: en un grafo de precedencia, si la tarea A debe ejecutarse antes que B, y B antes que C, entonces implícitamente A debe ejecutarse antes que C. Los ciclos en este contexto no tienen sentido lógico (¿cómo puede A depender de B y B depender de A simultáneamente?), por eso usamos un grafo acíclico.
Para la representación interna, utilizamos listas de adyacencia en lugar de matrices de adyacencia. Esta decisión de diseño es fundamental: mientras que una matriz requiere O(V²) espacio (donde V es el número de vértices), las listas de adyacencia solo requieren O(V + E) espacio (donde E es el número de aristas). En grafos dispersos, que son comunes en problemas reales de precedencia, esto representa un ahorro significativo de memoria. Además, iterar sobre los vecinos de un nodo es O(grado del nodo) con listas, versus O(V) con matrices.
javaprivate final Map<String, Vertice> vertices = new LinkedHashMap<>();
private final Map<String, Lado> lados = new LinkedHashMap<>();
private final Map<Vertice, LinkedHashSet<Vertice>> adj = new LinkedHashMap<>();
Observe el uso de LinkedHashMap en lugar de HashMap. Esto es intencional: necesitamos mantener el orden de inserción para que cuando procesemos los vértices, lo hagamos en un orden predecible y consistente. Si usáramos HashMap regular, el orden sería arbitrario y no determinístico, lo cual dificultaría la depuración y haría que los resultados fueran impredecibles entre ejecuciones.
Gestión de Vértices y Aristas
La clase Vertice no es simplemente un contenedor de etiquetas. Cada vértice mantiene información crucial sobre su conectividad: el grado interno (cuántas aristas llegan a él) y el grado externo (cuántas aristas salen de él). Esta información es esencial para el algoritmo de ordenamiento topológico que veremos después.
javapublic class Vertice {
    private final String etiqueta;
    private int gradoInt;  // Dependencias que deben completarse antes
    private int gradoExt;  // Tareas que dependen de esta
}
El grado interno tiene un significado semántico importante: representa el número de tareas que deben completarse antes de que este vértice pueda ejecutarse. Un vértice con grado interno 0 puede ejecutarse inmediatamente porque no tiene dependencias pendientes.
La clase Lado representa las aristas dirigidas del grafo. Cada lado tiene un vértice inicial (origen) y un vértice terminal (destino), lo que establece la relación de precedencia. Además, soporta multiplicidad para multigrafos, aunque en nuestro caso de grafos de precedencia típicamente no necesitamos aristas múltiples entre los mismos nodos.
El Algoritmo de Ordenamiento Topológico (Kahn)
Fundamento Teórico
El algoritmo de Kahn es la pieza central de todo el sistema. Un ordenamiento topológico de un grafo dirigido es una ordenación lineal de sus vértices tal que para cada arista dirigida (u, v), el vértice u viene antes que v en el ordenamiento. En términos de precedencia: si construimos una lista donde las tareas aparecen en orden topológico, garantizamos que ninguna tarea aparece antes de sus prerequisitos.
La belleza del algoritmo de Kahn radica en su simplicidad conceptual: procesa los nodos que están "listos" (sin dependencias pendientes), y al procesarlos, actualiza el estado de sus sucesores. Es como ir completando tareas en un proyecto: cuando terminas una tarea, todas las tareas que dependían de ella tienen una dependencia menos que satisfacer.
Implementación Detallada
javaprivate List<Vertice> ordenTopologico(boolean ascendente) {
    // Paso 1: Copiar grados internos
    Map<Vertice, Integer> gradosIn = new HashMap<>();
    for (Vertice v : vertices.values()) {
        gradosIn.put(v, v.obtGradoInt());
    }
El primer paso es crucial: copiamos los grados internos porque vamos a modificarlos durante el algoritmo. No queremos alterar el grafo original porque podríamos necesitarlo después para otras operaciones. Esta copia nos da una estructura de trabajo independiente.
java    // Paso 2: Cola de prioridad para orden determinístico
    PriorityQueue<Vertice> cola = new PriorityQueue<>((v1, v2) -> {
        String e1 = v1.obtEtiqueta();
        String e2 = v2.obtEtiqueta();
        try {
            int n1 = Integer.parseInt(e1.replaceAll("\\D+", ""));
            int n2 = Integer.parseInt(e2.replaceAll("\\D+", ""));
            return ascendente ? Integer.compare(n1, n2) : Integer.compare(n2, n1);
        } catch (NumberFormatException ex) {
            return ascendente ? e1.compareTo(e2) : e2.compareTo(e1);
        }
    });
Aquí usamos una PriorityQueue en lugar de una cola simple. ¿Por qué? Porque cuando múltiples nodos tienen grado interno 0 simultáneamente, el orden en que los procesemos afecta el resultado final. Al usar una cola de prioridad que ordena por el número en la etiqueta (S1 < S2 < S3...), garantizamos un resultado determinístico y legible. Sin esto, si S2 y S5 estuvieran ambos listos, podríamos procesar cualquiera primero, generando diferentes (aunque válidos) ordenamientos topológicos en diferentes ejecuciones.
java    // Paso 3: Inicializar con nodos sin dependencias
    for (Vertice v : vertices.values()) {
        if (gradosIn.get(v) == 0) {
            cola.add(v);
        }
    }
Comenzamos agregando todos los vértices con grado interno 0 a la cola. Estos son los "nodos raíz" del grafo de precedencia, las tareas que pueden comenzar inmediatamente sin esperar a nada más. En un proyecto, serían las primeras tareas que se pueden iniciar el día uno.
java    List<Vertice> resultado = new ArrayList<>();
    
    while (!cola.isEmpty()) {
        Vertice actual = cola.poll();
        resultado.add(actual);
        
        for (Vertice vecino : adj.getOrDefault(actual, new LinkedHashSet<>())) {
            int nuevoGrado = gradosIn.get(vecino) - 1;
            gradosIn.put(vecino, nuevoGrado);
            if (nuevoGrado == 0) {
                cola.add(vecino);
            }
        }
    }
Este bucle es donde ocurre la magia. En cada iteración:

Extraemos el nodo de mayor prioridad (menor número) que está listo
Lo agregamos a la lista resultado - este nodo ya tiene su posición final
Decrementamos el grado interno de todos sus vecinos - conceptualmente, estamos "completando" esta tarea
Si algún vecino llega a grado 0, significa que todas sus dependencias están satisfechas, así que lo agregamos a la cola de nodos listos

La invariante del algoritmo es: en cualquier momento, un nodo está en la cola si y solo si todas sus dependencias han sido procesadas.
java    // Paso 4: Detección de ciclos
    return (resultado.size() == vertices.size()) ? resultado : null;
}
Esta verificación final es elegante y poderosa. Si el algoritmo procesa exitosamente todos los vértices, el grafo es acíclico y tenemos un ordenamiento topológico válido. Si quedan vértices sin procesar, significa que hay un ciclo: esos vértices restantes están esperando entre sí en un ciclo de dependencias, y ninguno puede procesarse porque todos tienen grado interno > 0. Retornamos null para indicar esta situación de error.
Análisis de Complejidad:

Inicialización de grados: O(V)
Encontrar nodos con grado 0: O(V)
Bucle principal: procesa cada vértice una vez O(V) y cada arista una vez O(E)
Complejidad total: O(V + E) - lineal en el tamaño del grafo

Cálculo de Niveles de Ejecución
Concepto de Niveles
Una vez que tenemos el ordenamiento topológico, el siguiente paso es determinar los niveles de ejecución. El nivel de un nodo representa la distancia máxima desde cualquier nodo raíz hasta ese nodo. Este concepto es fundamental para identificar el paralelismo: todos los nodos en el mismo nivel pueden ejecutarse simultáneamente porque no tienen dependencias entre sí dentro de ese nivel.
javaprivate Map<Vertice, Integer> calcularNiveles() {
    List<Vertice> topo = ordenTopologicoMenor();
    if (topo == null) {
        throw new IllegalStateException("El grafo tiene ciclos");
    }
    
    Map<Vertice, Integer> nivel = new HashMap<>();
    for (Vertice v : vertices.values()) {
        nivel.put(v, 0);
    }
Primero obtenemos el ordenamiento topológico y inicializamos todos los niveles a 0. La inicialización a 0 es correcta porque los nodos raíz (sin dependencias) efectivamente están en el nivel 0.
java    for (Vertice v : topo) {
        int nv = nivel.get(v);
        for (Vertice vecino : adj.getOrDefault(v, new LinkedHashSet<>())) {
            int actual = nivel.getOrDefault(vecino, 0);
            if (nv + 1 > actual) {
                nivel.put(vecino, nv + 1);
            }
        }
    }
    return nivel;
}
```

El algoritmo es intuitivo: para cada vértice en orden topológico, propagamos su nivel a sus vecinos. Si estamos en el nivel N, nuestros sucesores deben estar al menos en el nivel N+1. Tomamos el máximo porque un nodo puede ser alcanzable por múltiples caminos, y debe estar en el nivel del camino más largo.

**Ejemplo concreto:**
```
    S1 (nivel 0)
   /  \
  S2   S3 (nivel 1)
   \  /
    S4 (nivel 2)
S4 tiene dos predecesores (S2 y S3), ambos en nivel 1. Por tanto, S4 debe estar en nivel 2, no en nivel 1, porque debe esperar a que AMBOS terminen.
¿Por qué funciona el orden topológico aquí? Porque garantiza que cuando procesamos un nodo, ya hemos procesado todos sus predecesores. Por tanto, cuando calculamos el nivel de un nodo, los niveles de todos sus predecesores ya están finalizados.
Generación del Código FORK/JOIN
Semántica FORK/JOIN
Antes de ver la implementación, entendamos qué significa el código FORK/JOIN:

FORK etiqueta: Crea un nuevo hilo de ejecución que salta a la etiqueta especificada
JOIN contador: Decrementa el contador; si llega a 0, continúa; si no, el hilo termina
contador = N: Inicializa un contador compartido para sincronización

La idea es: cuando tenemos K tareas en paralelo, creamos un contador en K, hacemos FORK para K-1 hilos nuevos, ejecutamos la tarea principal, cada hilo hace JOIN (decrementa el contador), y solo cuando los K hilos terminan (contador = 0), podemos continuar con el siguiente nivel.
Implementación del Generador
javapublic void imprimirCodigoForkJoin() {
    if (!orientado) {
        throw new IllegalStateException("El grafo debe ser dirigido");
    }
    
    Map<Vertice, Integer> nivel = calcularNiveles();
    
    // Encontrar nivel máximo
    int maxNivel = 0;
    for (int n : nivel.values()) {
        if (n > maxNivel) maxNivel = n;
    }
Primero calculamos los niveles y determinamos cuántos niveles de ejecución tenemos. Esto nos dice cuántas "fases" de ejecución secuencial necesitamos.
java    // Agrupar vértices por nivel
    Map<Integer, List<Vertice>> porNivel = new LinkedHashMap<>();
    for (int l = 0; l <= maxNivel; l++) {
        porNivel.put(l, new ArrayList<>());
    }
    for (Vertice v : vertices.values()) {
        int l = nivel.getOrDefault(v, 0);
        porNivel.get(l).add(v);
    }
Agrupamos los vértices por nivel. Esto nos permite procesar nivel por nivel, generando código secuencial entre niveles pero paralelo dentro de cada nivel.
java    // Comparador para orden consistente
    Comparator<Vertice> cmp = (v1, v2) -> {
        String e1 = v1.obtEtiqueta();
        String e2 = v2.obtEtiqueta();
        try {
            int n1 = Integer.parseInt(e1.replaceAll("\\D+", ""));
            int n2 = Integer.parseInt(e2.replaceAll("\\D+", ""));
            return Integer.compare(n1, n2);
        } catch (NumberFormatException ex) {
            return e1.compareTo(e2);
        }
    };
Este comparador garantiza que los nodos se procesen en orden numérico (S1, S2, S3...) dentro de cada nivel. Esto hace que el código generado sea legible y predecible.
java    int contadorEtiquetas = 1;
    
    for (int l = 0; l <= maxNivel; l++) {
        List<Vertice> nodos = porNivel.get(l);
        if (nodos == null || nodos.isEmpty()) continue;
        
        nodos.sort(cmp);
Iteramos nivel por nivel. El contador de etiquetas incrementa continuamente para dar etiquetas únicas a cada instrucción (L1, L2, L3...).
Caso 1: Nivel con un Solo Nodo (Ejecución Secuencial)
java        if (nodos.size() == 1 && l == 0) {
            Vertice v = nodos.get(0);
            System.out.println("L" + contadorEtiquetas + ": " + v.obtEtiqueta() + ";  // nivel " + l);
            contadorEtiquetas++;
        } else if (nodos.size() == 1) {
            Vertice v = nodos.get(0);
            System.out.println("// Nivel " + l);
            System.out.println("L" + contadorEtiquetas + ": " + v.obtEtiqueta() + ";");
            contadorEtiquetas++;
        }
```

Cuando un nivel tiene un solo nodo, no hay paralelismo posible en ese nivel. Simplemente generamos una instrucción secuencial. Esto es eficiente: no creamos hilos innecesariamente cuando no hay paralelismo que explotar.

**Ejemplo de salida:**
```
L1: S1;  // nivel 0
// Nivel 1
L2: S2;
Caso 2: Nivel con Múltiples Nodos (Ejecución Paralela)
java        } else {
            int k = nodos.size();
            System.out.println("// Nivel " + l + " (paralelo: " + k + " sentencias)");
            System.out.println("cont" + l + " = " + k + ";");
Cuando tenemos K nodos en el mismo nivel, necesitamos ejecutarlos en paralelo. Primero imprimimos un comentario explicativo y creamos un contador compartido inicializado en K. Este contador será decrementado por cada hilo al terminar.
java            // FORK para crear hilos adicionales (ramas 2..k)
            for (int idx = 1; idx < k; idx++) {
                Vertice v = nodos.get(idx);
                System.out.println("FORK L" + (contadorEtiquetas + idx)
                        + ";  // rama para " + v.obtEtiqueta());
            }
Generamos K-1 instrucciones FORK. ¿Por qué K-1 y no K? Porque ya tenemos el hilo principal que ejecutará la primera tarea. Cada FORK crea un nuevo hilo que salta a una etiqueta específica donde ejecutará su tarea asignada.
java            // Rama principal ejecuta la primera tarea
            Vertice v0 = nodos.get(0);
            System.out.println("L" + contadorEtiquetas + ": " + v0.obtEtiqueta() + ";");
            System.out.println("JOIN cont" + l + ";");
El hilo principal no hace un salto - simplemente continúa y ejecuta la primera tarea inmediatamente. Después de ejecutarla, hace JOIN, que decrementa el contador. Si es el último en terminar (contador llega a 0), continúa con el siguiente nivel. Si no, este hilo termina.
java            // Ramas paralelas ejecutan las demás tareas
            for (int idx = 1; idx < k; idx++) {
                Vertice v = nodos.get(idx);
                System.out.println("L" + (contadorEtiquetas + idx) + ": " + v.obtEtiqueta() + ";");
                System.out.println("JOIN cont" + l + ";");
            }
            
            contadorEtiquetas += k;
        }
    }
}
```

Finalmente, generamos el código para cada hilo paralelo. Cada uno tiene su etiqueta (hacia donde saltó el FORK correspondiente), ejecuta su tarea, y hace JOIN.

**Ejemplo de salida completo:**
```
// Nivel 0
L1: S1;

// Nivel 1 (paralelo: 3 sentencias)
cont1 = 3;
FORK L3;  // rama para S3
FORK L4;  // rama para S4
L2: S2;   // hilo principal
JOIN cont1;
L3: S3;   // hilo creado por primer FORK
JOIN cont1;
L4: S4;   // hilo creado por segundo FORK
JOIN cont1;

// Nivel 2
L5: S5;
Análisis de Corrección del Algoritmo
La corrección del código generado se basa en varias invariantes:

Respeto de dependencias: Los niveles se ejecutan secuencialmente. Un nivel L+1 solo comienza cuando todos los nodos del nivel L han terminado (gracias al mecanismo JOIN con contador).
No hay condiciones de carrera: Los nodos dentro del mismo nivel no tienen dependencias entre sí (por construcción del algoritmo de niveles), por tanto pueden ejecutarse en cualquier orden o simultáneamente sin problemas.
Terminación garantizada: Como el grafo es acíclico (verificado por el ordenamiento topológico), no hay deadlocks posibles. Cada nivel eventualmente completa, permitiendo que el siguiente comience.
Máximo paralelismo: Si K tareas pueden ejecutarse en paralelo (están en el mismo nivel), las ejecutamos en paralelo. No desperdiciamos oportunidades de paralelismo.

Interfaz Gráfica y Visualización
Arquitectura de la Interfaz (InterfazGrafica.java)
La interfaz gráfica proporciona una forma amigable de interactuar con el sistema. Está construida con Java Swing y sigue un patrón de diseño MVC simplificado.
javapublic class InterfazGrafica extends JFrame {
    private JTextArea areaGrafo;        // Muestra info del grafo
    private JTextArea areaForkJoin;     // Muestra código generado
    private JTextArea areaDOT;          // Muestra código Graphviz
    private PanelGrafico panelGrafico;  // Visualización gráfica
    private Grafo grafoActual;          // Modelo
La interfaz tiene cuatro áreas principales de visualización, cada una en su propia pestaña:

Visualización Gráfica: Dibuja el grafo con nodos y aristas
Información del Grafo: Muestra texto con vértices, aristas y estructura
Código FORK/JOIN: Muestra el código paralelo generado
Código Graphviz DOT: Para exportar a otras herramientas de visualización

Algoritmo de Visualización Gráfica
La clase PanelGrafico implementa un algoritmo de layout para dibujar el grafo de forma comprensible:
javaprivate void calcularPosiciones() {
    if (grafo == null) return;
    
    // Calcular niveles de cada nodo
    Map<Vertice, Integer> niveles = calcularNiveles();
    
    // Agrupar por nivel
    Map<Integer, List<Vertice>> porNivel = new HashMap<>();
    int maxNivel = 0;
    
    for (Vertice v : vertices) {
        int nivel = niveles.getOrDefault(v, 0);
        if (nivel > maxNivel) maxNivel = nivel;
        
        porNivel.putIfAbsent(nivel, new ArrayList<>());
        porNivel.get(nivel).add(v);
    }
El algoritmo aprovecha los niveles que ya calculamos. La idea es organizar el grafo horizontalmente por niveles: nivel 0 a la izquierda, nivel 1 más a la derecha, etc. Esto crea un layout que refleja visualmente el flujo de ejecución temporal.
java    int anchoDisponible = getPreferredSize().width - 2 * MARGEN;
    int altoDisponible = getPreferredSize().height - 2 * MARGEN;
    
    for (int nivel = 0; nivel <= maxNivel; nivel++) {
        List<Vertice> nodosNivel = porNivel.get(nivel);
        if (nodosNivel == null) continue;
        
        // Posición X: proporcional al nivel
        int x = MARGEN + (nivel * anchoDisponible / (maxNivel + 1));
        
        // Distribuir verticalmente los nodos del mismo nivel
        int espacioVertical = altoDisponible / (nodosNivel.size() + 1);
        
        for (int i = 0; i < nodosNivel.size(); i++) {
            Vertice v = nodosNivel.get(i);
            int y = MARGEN + espacioVertical * (i + 1);
            posiciones.put(v.obtEtiqueta(), new Point(x, y));
        }
    }
}
Para cada nivel:

Posición horizontal (X): Proporcional al número de nivel. Nivel 0 cerca del margen izquierdo, nivel máximo cerca del margen derecho.
Posición vertical (Y): Los nodos del mismo nivel se distribuyen uniformemente en el espacio vertical disponible.

Este layout tiene ventajas importantes:

Claridad visual: El flujo de izquierda a derecha muestra el orden temporal
Identificación del paralelismo: Nodos en la misma columna vertical = ejecución paralela
Sin cruces innecesarios: Las aristas generalmente fluyen de izquierda a derecha sin entrecruzarse

Renderizado de Aristas con Flechas
javaprivate void dibujarFlecha(Graphics2D g2d, int x1, int y1, int x2, int y2) {
    double angulo = Math.atan2(y2 - y1, x2 - x1);
    int longitudFlecha = 12;
    int anguloFlecha = 25;
    
    double angulo1 = angulo - Math.toRadians(anguloFlecha);
    double angulo2 = angulo + Math.toRadians(anguloFlecha);
    
    int x3 = x2 - (int)(longitudFlecha * Math.cos(angulo1));
    int y3 = y2 - (int)(longitudFlecha * Math.sin(angulo1));
    int x4 = x2 - (int)(longitudFlecha * Math.cos(angulo2));
    int y4 = y2 - (int)(longitudFlecha * Math.sin(angulo2));
    
    g2d.drawLine(x2, y2, x3, y3);
    g2d.drawLine(x2, y2, x4, y4);
}
Este método dibuja flechas en las aristas para indicar la dirección de la dependencia. Usa trigonometría para calcular los puntos de la punta de la flecha:

Calcula el ángulo de la línea principal
Crea dos líneas que salen del punto final, rotadas ±25° respecto al ángulo principal
Esto forma una punta de flecha en "V"

El cálculo considera el radio de los nodos para que las flechas comiencen/terminen en el borde del círculo, no en el centro.
Formato Graphviz DOT
javapublic void imprimirGraphvizDOT() {
    System.out.println("digraph G {");
    System.out.println("  rankdir=LR;");
    System.out.println("  node [shape=circle];");
    
    for (Vertice v : vertices.values()) {
        System.out.println("  " + v.obtEtiqueta() + ";");
    }
    
    for (Lado lado : lados.values()) {
        System.out.println("  " + lado.obtVInicial().obtEtiqueta()
                + " -> " + lado.obtVTerminal().obtEtiqueta() + ";");
    }
    
    System.out.println("}");
}
El formato DOT es un estándar para representar grafos. El código generado puede copiarse directamente en herramientas como Graphviz Online, que producirán visualizaciones profesionales. La opción rankdir=LR (rank direction = left to right) hace que el grafo se dibuje horizontalmente, igual que en nuestra visualización interna.
Gestión de Archivos y Entrada de Datos
Lectura de Matriz de Adyacencia
javapublic static Grafo desdeArchivoMatriz(String nombreArchivo) throws IOException {
    List<int[]> filas = new ArrayList<>();
    
    try (BufferedReader br = new BufferedReader(new FileReader(nombreArchivo))) {
        String linea;
        while ((linea = br.readLine()) != null) {
            linea = linea.trim();
            if (linea.isEmpty()) continue;
            
            String[] partes = linea.split("\\s+");
            int[] fila = new int[partes.length];
            for (int i = 0; i < partes.length; i++) {
                fila[i] = Integer.parseInt(partes[i]);
            }
            filas.add(fila);
        }
    }
```

El método lee una matriz de adyacencia desde un archivo de texto. Formato esperado:
```
0 1 1 0
0 0 0 1
0 0 0 1
0 0 0 0
Donde matriz[i][j] = 1 significa que existe una arista de Si a Sj (Si debe ejecutarse antes que Sj).
java    int n = filas.size();
    if (n == 0) {
        throw new IllegalArgumentException("El archivo esta vacio");
    }
    
    Grafo g = new Grafo(true); // dirigido
    
    // Crear vértices S1..Sn
    for (int i = 1; i <= n; i++) {
        g.agregarVertice(new Vertice("S" + i));
    }
Creamos un grafo dirigido y añadimos n vértices con nomenclatura estándar S1, S2, ..., Sn.
java    // Agregar arcos según la matriz
    for (int i = 0; i < n; i++) {
        int[] fila = filas.get(i);
        if (fila.length != n) {
            throw new IllegalArgumentException("La matriz debe ser cuadrada");
        }
        for (int j = 0; j < n; j++) {
            if (fila[j] == 1) {
                Vertice u = g.get("S" + (i + 1));
                Vertice v = g.get("S" + (j + 1));
                g.agregarLado(u, v);
            }
        }
    }
    
    return g;
}
```

Recorremos la matriz y por cada 1 en la posición [i][j], creamos una arista de Si+1 a Sj+1. La validación de matriz cuadrada es importante: una matriz no cuadrada no representa un grafo válido.

## Casos de Uso y Ejemplos

### Ejemplo 1: Grafo Lineal Simple

**Entrada (matriz):**
```
0 1 0 0
0 0 1 0
0 0 0 1
0 0 0 0
```

**Interpretación:** S1→S2→S3→S4 (cadena lineal)

**Niveles calculados:**
- S1: nivel 0
- S2: nivel 1
- S3: nivel 2
- S4: nivel 3

**Código FORK/JOIN generado:**
```
L1: S1;
L2: S2;
L3: S3;
L4: S4;
Sin paralelismo, solo ejecución secuencial. El sistema reconoce esto y no genera FORK/JOIN innecesarios.
Ejemplo 2: Paralelismo Total
Entrada (matriz):                                              
0 0 0 0
0 0 0 0
0 0 0 0
0 0 0 0

**Interpretación:** Cuatro tareas independientes sin dependencias

**Niveles calculados:**
- S1, S2, S3, S4: todos nivel 0

**Código FORK/JOIN generado:**
// Nivel 0 (paralelo: 4 sentencias)
cont0 = 4;
FORK L2;
FORK L3;
FORK L4;
L1: S1;
JOIN cont0;
L2: S2;
JOIN cont0;
L3: S3;
JOIN cont0;
L4: S4;
JOIN cont0;

Paralelismo máximo: las cuatro tareas se ejecutan simultáneamente.

### Ejemplo 3: Grafo Tipo Diamante

**Entrada (matriz):**
0 1 1 0
0 0 0 1
0 0 0 1
0 0 0 0

**Interpretación:**
