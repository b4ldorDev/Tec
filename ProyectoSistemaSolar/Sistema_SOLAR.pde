import peasy.*;
import processing.sound.*;  // Librería de sonido de Processing

// Texturas para los planetas y el sol
PImage texturaSol;
PImage texturaMercurio;
PImage texturaVenus;
PImage texturaTierra;
PImage texturaMarte;
PImage texturaJupiter;
PImage texturaSaturno;
PImage texturaUrano;
PImage texturaNeptuno;
PImage texturaPluto;

// Objetos principales del sistema
PeasyCam camara;       // Para movernos por el espacio
Planeta sol;           // El centro de nuestro sistema
FondoEstelar espacio;  // El fondo con estrellitas

// Variables para control manual de planetas
int planetaSeleccionado = 0;       // Índice del planeta seleccionado (0=sol)
boolean modoManual = false;        // Modo de control manual
float velocidadMovimiento = 2.0;   // Velocidad de movimiento de los planetas
int colorNeon = #00FF00;           // Color verde neón para destacar elementos
PFont fuenteInstrucciones;         // Fuente para instrucciones
boolean texturasCargadas = true;   // Flag para controlar si las texturas cargaron correctamente

// Variables para el audio
SoundFile musicaFondo;
boolean musicaSonando = false;
float volumen = 0.8; // 80% del volumen máximo

void setup() {
  // Crear ventana grande para ver todo bien
  size(1200, 600, P3D);
  
  // Intentar cargar una fuente que tengamos disponible
  try {
    fuenteInstrucciones = createFont("Arial", 14);
  } catch (Exception e) {
    fuenteInstrucciones = createFont("SansSerif", 14);
  }
  
  // Inicializar la cámara (el 400 es para no empezar tan cerca)
  camara = new PeasyCam(this, 400);
  
  // Cargar la música de fondo
  try {
    musicaFondo = new SoundFile(this, "AereoManu.mp3"); // Asegúrate de tener este archivo en la carpeta "data"
    musicaFondo.amp(volumen); // Establecer el volumen
    // No reproducir automáticamente, esperar a que el usuario presione 'P'
  } catch (Exception e) {
    println("No se pudo cargar la música: " + e.getMessage());
  }
  
  // Cargar todas las texturas de los archivos
  try {
    texturaSol = loadImage("sunmap.jpg");
    texturaMercurio = loadImage("mercurymap.jpg");
    texturaVenus = loadImage("venusmap.jpg");
    texturaTierra = loadImage("earthmap1k.jpg");
    texturaMarte = loadImage("mars_1k_color.jpg");
    texturaJupiter = loadImage("jupitermap.jpg");
    texturaSaturno = loadImage("saturnmap.jpg");
    texturaUrano = loadImage("uranusmap.jpg");
    texturaNeptuno = loadImage("neptunemap.jpg");
    texturaPluto = loadImage("plutomap1k.jpg");
    
    // Verificar si las texturas se cargaron correctamente
    if (texturaSol == null || texturaMercurio == null || texturaVenus == null || texturaTierra == null) {
      texturasCargadas = false;
      println("Algunas texturas importantes no se pudieron cargar.");
    }
    
  } catch (Exception e) {
    // Si hay error al cargar las texturas, continuamos sin ellas
    println("No se pudieron cargar todas las texturas: " + e.getMessage());
    texturasCargadas = false;
  }
  
  // Crear un fondo espacial con estrellas
  espacio = new FondoEstelar(1000);
  
  // Armar todo el sistema solar
  crearSistemaSolar();
  
  // Configuración para texturas
  textureMode(NORMAL);
  
  // Configuración de luces
  lights(); // Activar iluminación básica
  directionalLight(255, 255, 255, 0, 0, -1); // Luz direccional para mejor visualización
}

void draw() {
  // Fondo negro
  background(0);
  
  // Poner el fondo de estrellas
  pushMatrix();
  resetMatrix();
  hint(DISABLE_DEPTH_TEST);
  espacio.mostrar();
  hint(ENABLE_DEPTH_TEST);
  popMatrix();
  
  // Configuración de luces (actualizamos cada frame para asegurar consistencia)
  lights();
  directionalLight(255, 255, 255, 0, 0, -1);
  
  // Si estamos en modo manual, mostrar información del planeta seleccionado
  if (modoManual) {
    pushMatrix();
    resetMatrix();
    hint(DISABLE_DEPTH_TEST);
    mostrarInfoPlanetaSeleccionado();
    hint(ENABLE_DEPTH_TEST);
    popMatrix();
  }
  
  // Mostrar instrucciones siempre visibles
  pushMatrix();
  resetMatrix();
  hint(DISABLE_DEPTH_TEST);
  mostrarInstrucciones();
  hint(ENABLE_DEPTH_TEST);
  popMatrix();
  
  // Actualizar y mostrar todo el sistema solar
  sol.actualizar();
  sol.mostrar();
}

// Función para mostrar instrucciones fijas en la pantalla
void mostrarInstrucciones() {
  // Establecer fuente y alineación
  textFont(fuenteInstrucciones);
  textAlign(LEFT, BOTTOM);
  
  // Panel semi-transparente grande para todas las instrucciones
  fill(0, 200);
  noStroke();
  rect(10, height - 170, 380, 160, 5);
  
  // Instrucciones
  fill(255); // Color blanco para las instrucciones
  textSize(14);
  text("CONTROLES:", 20, height - 150);
  text("R: Resetear cámara", 20, height - 130);
  text("M: " + (modoManual ? "Desactivar" : "Activar") + " modo manual", 20, height - 110);
  text("P: " + (musicaSonando ? "Pausar" : "Reproducir") + " música", 20, height - 90);
  text("+ / -: Subir/Bajar volumen", 20, height - 70);
  
  if (modoManual) {
    text("TAB: Cambiar planeta", 20, height - 50);
    text("↑/↓: Aumentar/Disminuir distancia", 20, height - 30);
    text("←/→: Mover en órbita", 20, height - 10);
  }
  
  // Mostrar autor y fecha
  textAlign(RIGHT, BOTTOM);
  text("b4ldorDev - 2025-06-10", width - 20, height - 10);
}

// Función para mostrar información del planeta seleccionado en modo manual
void mostrarInfoPlanetaSeleccionado() {
  // Dibujar panel de información en la esquina
  fill(0, 150);
  stroke(255); // Blanco para el borde
  rect(10, 10, 300, 80, 5);
  
  fill(255); // Texto blanco
  textFont(fuenteInstrucciones);
  textSize(16);
  textAlign(LEFT, CENTER);
  
  String nombrePlaneta = "Sol";
  if (planetaSeleccionado > 0) {
    switch(planetaSeleccionado - 1) { // -1 porque el índice 0 es el sol
      case 0: nombrePlaneta = "Mercurio"; break;
      case 1: nombrePlaneta = "Venus"; break;
      case 2: nombrePlaneta = "Tierra"; break;
      case 3: nombrePlaneta = "Marte"; break;
      case 4: nombrePlaneta = "Júpiter"; break;
      case 5: nombrePlaneta = "Saturno"; break;
      case 6: nombrePlaneta = "Urano"; break;
      case 7: nombrePlaneta = "Neptuno"; break;
    }
  }
  
  text("MODO MANUAL - " + nombrePlaneta, 20, 30);
  text("Flechas: Mover    Tab: Cambiar planeta", 20, 55);
  
  // Si está sonando música, mostrar información
  if (musicaSonando && musicaFondo != null) {
    fill(255, 150);
    textAlign(RIGHT, TOP);
    text("♫ AeroManu ♫", width - 20, 20);
    text("Volumen: " + int(volumen * 100) + "%", width - 20, 40);
  }
}

void crearSistemaSolar() {
  // Crear el Sol (sin distancia, sin velocidad, grandote y amarillo)
  sol = new Planeta(0, 0, 30, color(255, 255, 0), texturaSol, texturasCargadas);
  
  // Mercurio: el más cercano al sol, rápido y chiquito
  Planeta mercurio = new Planeta(60, 0.05, 3, color(180, 180, 180), texturaMercurio, texturasCargadas);
  
  // Venus: un poco más lejos, más lento y anaranjado
  Planeta venus = new Planeta(90, 0.03, 5, color(255, 150, 50), texturaVenus, texturasCargadas);
  
  // Tierra y su Luna
  Planeta tierra = new Planeta(120, 0.02, 6, color(50, 100, 255), texturaTierra, texturasCargadas);
  Luna lunaTierra = new Luna(20, 0.1, 2, color(200), null, texturasCargadas);
  tierra.agregarLuna(lunaTierra);
  
  // Marte con sus dos lunitas: Fobos y Deimos
  Planeta marte = new Planeta(160, 0.015, 4, color(200, 50, 50), texturaMarte, texturasCargadas);
  Luna fobos = new Luna(15, 0.08, 1.5, color(180), null, texturasCargadas);
  Luna deimos = new Luna(22, 0.06, 1.2, color(160), null, texturasCargadas);
  marte.agregarLuna(fobos);
  marte.agregarLuna(deimos);
  
  // Júpiter con sus 4 lunas más grandes
  Planeta jupiter = new Planeta(220, 0.01, 12, color(255, 200, 100), texturaJupiter, texturasCargadas);
  // Creamos 4 lunas para Júpiter
  for (int i = 0; i < 4; i++) {
    float distancia = 25 + i * 5;
    float velocidad = 0.07 - i * 0.01;
    float tamaño = 2 - i * 0.05;
    Luna lunaJupiter = new Luna(distancia, velocidad, tamaño, color(220 - i * 10), null, texturasCargadas);
    jupiter.agregarLuna(lunaJupiter);
  }
  
  // Saturno con sus lunas
  Planeta saturno = new Planeta(280, 0.008, 10, color(240, 220, 150), texturaSaturno, texturasCargadas);
  Luna lunaSaturno1 = new Luna(28, 0.05, 2, color(220), null, texturasCargadas);
  Luna lunaSaturno2 = new Luna(34, 0.04, 1.5, color(210), null, texturasCargadas);
  saturno.agregarLuna(lunaSaturno1);
  saturno.agregarLuna(lunaSaturno2);
  
  // Urano con sus lunas
  Planeta urano = new Planeta(340, 0.006, 8, color(150, 200, 255), texturaUrano, texturasCargadas);
  Luna lunaUrano1 = new Luna(20, 0.05, 1.5, color(180), null, texturasCargadas);
  Luna lunaUrano2 = new Luna(25, 0.03, 1.5, color(190), null, texturasCargadas);
  urano.agregarLuna(lunaUrano1);
  urano.agregarLuna(lunaUrano2);
  
  // Neptuno con su luna
  Planeta neptuno = new Planeta(400, 0.004, 8, color(50, 100, 200), texturaNeptuno, texturasCargadas);
  Luna lunaNeptuno = new Luna(22, 0.05, 1.7, color(150), null, texturasCargadas);
  neptuno.agregarLuna(lunaNeptuno);
  
  // Agregar todos los planetas al sol
  sol.agregarPlaneta(mercurio);
  sol.agregarPlaneta(venus);
  sol.agregarPlaneta(tierra);
  sol.agregarPlaneta(marte);
  sol.agregarPlaneta(jupiter);
  sol.agregarPlaneta(saturno);
  sol.agregarPlaneta(urano);
  sol.agregarPlaneta(neptuno);
}

// Método para obtener un planeta específico por su índice
Planeta obtenerPlanetaPorIndice(int indice) {
  if (indice == 0) return sol;  // El sol es el índice 0
  
  // De lo contrario, buscamos en la lista de planetas del sol
  if (indice > 0 && indice <= sol.planetas.size()) {
    return sol.planetas.get(indice - 1);  // -1 porque el índice 0 es el sol
  }
  
  return null;  // Si no encontramos el planeta
}

// Control de teclado
void keyPressed() {
  // Controles cuando estamos en la simulación
  if (key == 'r' || key == 'R') {
    camara.reset();
  } else if (key == 'm' || key == 'M') {
    modoManual = !modoManual;
    camara.setActive(!modoManual);  // Activar/desactivar cámara según el modo
  } else if (key == TAB) {
    // Cambiar planeta seleccionado
    planetaSeleccionado = (planetaSeleccionado + 1) % 9;  // 9 cuerpos (sol + 8 planetas)
  } else if (key == 'p' || key == 'P') {
    // Reproducir o pausar la música
    if (musicaFondo != null) {
      if (musicaSonando) {
        musicaFondo.pause();
      } else {
        musicaFondo.play();
      }
      musicaSonando = !musicaSonando;
    }
  } else if (key == '+' || key == '=') {
    // Subir volumen
    if (musicaFondo != null) {
      volumen = constrain(volumen + 0.1, 0, 1.0);
      musicaFondo.amp(volumen);
    }
  } else if (key == '-' || key == '_') {
    // Bajar volumen
    if (musicaFondo != null) {
      volumen = constrain(volumen - 0.1, 0, 1.0);
      musicaFondo.amp(volumen);
    }
  }
  
  // Control de planetas con flechas en modo manual
  if (modoManual) {
    Planeta planetaActual = obtenerPlanetaPorIndice(planetaSeleccionado);
    if (planetaActual != null) {
      if (keyCode == UP) {
        // Aumentar la distancia al centro
        planetaActual.distancia += velocidadMovimiento;
      } else if (keyCode == DOWN) {
        // Disminuir la distancia al centro (con límite)
        planetaActual.distancia = max(planetaActual.distancia - velocidadMovimiento, 
                                      planetaActual == sol ? 0 : planetaActual.radio * 2);
      } else if (keyCode == LEFT) {
        // Mover hacia atrás en la órbita
        planetaActual.angulo -= 0.05;
      } else if (keyCode == RIGHT) {
        // Mover hacia adelante en la órbita
        planetaActual.angulo += 0.05;
      }
    }
  }
}
