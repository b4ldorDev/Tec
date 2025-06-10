import peasy.*;
import processing.sound.*;

// variables para las texturas de los planetas
PImage texturaSol, texturaMercurio, texturaVenus, texturaTierra, texturaMarte;
PImage texturaJupiter, texturaSaturno, texturaUrano, texturaNeptuno;

// objetos principales del sistema
PeasyCam camara;
Planeta sol;
FondoEstelar espacio;

// variables de control del programa
int planetaSeleccionado = 0;
boolean modoManual = false;
float velocidadMovimiento = 2.0;
PFont fuenteInstrucciones;
boolean texturasCargadas = true;

// variables para el control de audio
SoundFile musicaFondo;
boolean musicaSonando = false;
float volumen = 0.8;

// informacion del proyecto
String fechaActual = "2025-06-10 04:16:20";
String desarrolladores = " Desarrollado por Alberto Guillen Rayas e Ileana Tapia Castillo";

void setup() {
  fullScreen(P3D);
  
  // configuracion de la fuente para la interfaz
  try {
    fuenteInstrucciones = createFont("Silkscreen-Regular.ttf", 14);
    println("Fuente Silkscreen cargada correctamente");
  } catch (Exception e) {
    try {
      fuenteInstrucciones = createFont("data/Silkscreen-Regular.ttf", 14);
      println("Fuente Silkscreen cargada desde data/");
    } catch (Exception e2) {
      println("No se pudo cargar Silkscreen, usando fuente alternativa");
      fuenteInstrucciones = createFont("SansSerif", 14);
    }
  }
  
  // inicializacion de la camara con vista 3d
  camara = new PeasyCam(this, 400);
  
  // carga del archivo de musica de fondo
  try {
    musicaFondo = new SoundFile(this, "data/AereoManu.mp3");
    musicaFondo.amp(volumen);
    println("Musica cargada correctamente");
  } catch (Exception e1) {
    try {
      musicaFondo = new SoundFile(this, "AereoManu.mp3");
      musicaFondo.amp(volumen);
      println("Musica cargada correctamente desde raiz");
    } catch (Exception e2) {
      println("ERROR: No se pudo cargar la musica. Asegurate de que el archivo AereoManu.mp3 existe en la carpeta 'data'");
    }
  }
  
  // carga de las texturas para los planetas
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
    
    if (texturaSol == null || texturaMercurio == null || texturaVenus == null || texturaTierra == null) {
      texturasCargadas = false;
      println("Algunas texturas importantes no se pudieron cargar.");
    }
  } catch (Exception e) {
    println("No se pudieron cargar todas las texturas: " + e.getMessage());
    texturasCargadas = false;
  }
  
  espacio = new FondoEstelar(1000);
  crearSistemaSolar();
  
  textureMode(NORMAL);
  lights();
  directionalLight(255, 255, 255, 0, 0, -1);
}

void draw() {
  background(0);
  
  // dibujamos el fondo estelar
  pushMatrix();
  resetMatrix();
  hint(DISABLE_DEPTH_TEST);
  espacio.mostrar();
  hint(ENABLE_DEPTH_TEST);
  popMatrix();
  
  // configuracion de iluminacion
  lights();
  directionalLight(255, 255, 255, 0, 0, -1);
  
  // actualizacion y visualizacion del sistema solar
  sol.actualizar();
  sol.mostrar();
  
  // interfaz de usuario
  pushMatrix();
  resetMatrix();
  camara.beginHUD();
  
  if (modoManual) {
    mostrarInfoPlanetaSeleccionado();
  }
  
  mostrarInstrucciones();
  mostrarMenuInicial();
  camara.endHUD();
  popMatrix();
}

void mostrarMenuInicial() {
  // panel para el titulo y la informacion
  fill(0, 200);
  noStroke();
  rect(width/2 - 300, 10, 600, 80, 10);
  
  textFont(fuenteInstrucciones);
  textAlign(CENTER, CENTER);
  
  // titulo del proyecto
  fill(255, 255, 0);
  textSize(24);
  text("SISTEMA SOLAR INTERACTIVO", width/2, 35);
  
  // datos del proyecto
  fill(200, 200, 255);
  textSize(12);
  text("Fecha: " + fechaActual + " |" + desarrolladores, width/2, 65);
}

void mostrarInstrucciones() {
  textFont(fuenteInstrucciones);
  textAlign(LEFT, BOTTOM);
  
  // panel para las instrucciones
  fill(0, 230);
  noStroke();
  rect(10, height - 170, 380, 160, 5);
  
  // texto de instrucciones
  fill(255);
  textSize(14);
  text("CONTROLES:", 20, height - 150);
  textSize(12);
  text("R: Resetear camara", 20, height - 130);
  text("M: " + (modoManual ? "Desactivar" : "Activar") + " modo manual", 20, height - 110);
  text("P: " + (musicaSonando ? "Pausar" : "Reproducir") + " musica", 20, height - 90);
  text("+ / -: Subir/Bajar volumen", 20, height - 70);
  
  if (modoManual) {
    text("TAB: Cambiar planeta", 20, height - 50);
    text("↑/↓: Aumentar/Disminuir distancia", 20, height - 30);
    text("←/→: Mover en orbita", 20, height - 10);
  }
  
  // mensaje de error si no hay musica
  if (musicaFondo == null) {
    fill(255, 100, 100);
    textAlign(RIGHT, TOP);
    text("¡MUSICA NO DISPONIBLE!", width - 20, 20);
  }
  
  // creditos de la musica
  fill(255, 200);
  textAlign(RIGHT, BOTTOM);
  text("♫ Cancion: AeroManu - Creditos a Victor Manuel canchola Cervantes  A01711794 ♫", width - 20, height - 10);
}

void mostrarInfoPlanetaSeleccionado() {
  // panel para la informacion del planeta
  fill(0, 200);
  stroke(255);
  strokeWeight(1);
  rect(10, 10, 300, 80, 5);
  
  fill(255);
  textFont(fuenteInstrucciones);
  textSize(16);
  textAlign(LEFT, CENTER);
  
  String[] nombresPlanetas = {"Sol", "Mercurio", "Venus", "Tierra", "Marte", 
                             "Jupiter", "Saturno", "Urano", "Neptuno"};
  String nombrePlaneta = nombresPlanetas[planetaSeleccionado];
  
  text("MODO MANUAL - " + nombrePlaneta, 20, 30);
  textSize(12);
  text("Flechas: Mover    Tab: Cambiar planeta", 20, 55);
}

void crearSistemaSolar() {
  sol = new Planeta(0, 0, 30, color(255, 255, 0), texturaSol, texturasCargadas);
  
  // planetas internos
  Planeta mercurio = new Planeta(60, 0.05, 3, color(180, 180, 180), texturaMercurio, texturasCargadas);
  Planeta venus = new Planeta(90, 0.03, 5, color(255, 150, 50), texturaVenus, texturasCargadas);
  
  // la tierra y su luna
  Planeta tierra = new Planeta(120, 0.02, 6, color(50, 100, 255), texturaTierra, texturasCargadas);
  Luna lunaTierra = new Luna(20, 0.1, 2, color(200), null, texturasCargadas);
  tierra.agregarLuna(lunaTierra);
  
  // marte y sus lunas
  Planeta marte = new Planeta(160, 0.015, 4, color(200, 50, 50), texturaMarte, texturasCargadas);
  Luna fobos = new Luna(15, 0.08, 1.5, color(180), null, texturasCargadas);
  Luna deimos = new Luna(22, 0.06, 1.2, color(160), null, texturasCargadas);
  marte.agregarLuna(fobos);
  marte.agregarLuna(deimos);
  
  // jupiter y sus lunas principales
  Planeta jupiter = new Planeta(220, 0.01, 12, color(255, 200, 100), texturaJupiter, texturasCargadas);
  for (int i = 0; i < 4; i++) {
    Luna lunaJupiter = new Luna(25 + i * 5, 0.07 - i * 0.01, 2 - i * 0.05, color(220 - i * 10), null, texturasCargadas);
    jupiter.agregarLuna(lunaJupiter);
  }
  
  // saturno con sus lunas y anillos
  // nota: se deben implementar los anillos como un objeto adicional alrededor de saturno
  Planeta saturno = new Planeta(280, 0.008, 10, color(240, 220, 150), texturaSaturno, texturasCargadas);
  saturno.agregarLuna(new Luna(28, 0.05, 2, color(220), null, texturasCargadas));
  saturno.agregarLuna(new Luna(34, 0.04, 1.5, color(210), null, texturasCargadas));
  // para implementar los anillos: crear un objeto especial tipo anillo y asociarlo a saturno
  // o dibujar discos planos alrededor del planeta
  
  // planetas exteriores
  Planeta urano = new Planeta(340, 0.006, 8, color(150, 200, 255), texturaUrano, texturasCargadas);
  urano.agregarLuna(new Luna(20, 0.05, 1.5, color(180), null, texturasCargadas));
  urano.agregarLuna(new Luna(25, 0.03, 1.5, color(190), null, texturasCargadas));
  
  Planeta neptuno = new Planeta(400, 0.004, 8, color(50, 100, 200), texturaNeptuno, texturasCargadas);
  neptuno.agregarLuna(new Luna(22, 0.05, 1.7, color(150), null, texturasCargadas));
  
  // agregamos todos los planetas al sol
  sol.agregarPlaneta(mercurio);
  sol.agregarPlaneta(venus);
  sol.agregarPlaneta(tierra);
  sol.agregarPlaneta(marte);
  sol.agregarPlaneta(jupiter);
  sol.agregarPlaneta(saturno);
  sol.agregarPlaneta(urano);
  sol.agregarPlaneta(neptuno);
}

Planeta obtenerPlanetaPorIndice(int indice) {
  if (indice == 0) return sol;
  if (indice > 0 && indice <= sol.planetas.size()) {
    return sol.planetas.get(indice - 1);
  }
  return null;
}

void keyPressed() {
  if (key == 'r' || key == 'R') {
    camara.reset();
  } else if (key == 'm' || key == 'M') {
    modoManual = !modoManual;
    camara.setActive(!modoManual);
  } else if (key == TAB) {
    planetaSeleccionado = (planetaSeleccionado + 1) % 9;
  } else if (key == 'p' || key == 'P') {
    if (musicaFondo != null) {
      try {
        if (musicaSonando) {
          musicaFondo.pause();
          println("Musica pausada");
        } else {
          musicaFondo.play();
          println("Reproduciendo musica");
        }
        musicaSonando = !musicaSonando;
      } catch (Exception e) {
        println("Error al reproducir musica: " + e.getMessage());
      }
    }
  } else if (key == '+' || key == '=') {
    if (musicaFondo != null) {
      volumen = constrain(volumen + 0.1, 0, 1.0);
      musicaFondo.amp(volumen);
      println("Volumen: " + int(volumen * 100) + "%");
    }
  } else if (key == '-' || key == '_') {
    if (musicaFondo != null) {
      volumen = constrain(volumen - 0.1, 0, 1.0);
      musicaFondo.amp(volumen);
      println("Volumen: " + int(volumen * 100) + "%");
    }
  }
  
  // control de planetas en modo manual
  if (modoManual) {
    Planeta planetaActual = obtenerPlanetaPorIndice(planetaSeleccionado);
    if (planetaActual != null) {
      if (keyCode == UP) {
        planetaActual.distancia += velocidadMovimiento;
      } else if (keyCode == DOWN) {
        planetaActual.distancia = max(planetaActual.distancia - velocidadMovimiento, 
                                    planetaActual == sol ? 0 : planetaActual.radio * 2);
      } else if (keyCode == LEFT) {
        planetaActual.angulo -= 0.05;
      } else if (keyCode == RIGHT) {
        planetaActual.angulo += 0.05;
      }
    }
  }
}
