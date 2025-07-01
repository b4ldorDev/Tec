const GOOGLE_SHEET_URL = "https://script.google.com/a/macros/tec.mx/s/AKfycbxIcTC-5IdYEYzZ2COrnmt4PqdQB_GcWLn0Ld8NEaHIiNnIGKUM1dPomoPAWLRz7vNV/exec"
let currentSection = 0;
const totalSections = 2;
let surveyData = JSON.parse(localStorage.getItem('surveyData') || '[]');

function updateParticipantCounter() {
    document.getElementById('participantNumber').textContent = surveyData.length + 1;
}
updateParticipantCounter();

function updateProgress() {
    const progress = (currentSection / (totalSections - 1)) * 100;
    document.getElementById('progressFill').style.width = progress + '%';
}

function showSection(n) {
    const sections = document.querySelectorAll('.question-section');
    sections.forEach(section => section.classList.remove('active'));
    if (sections[n]) sections[n].classList.add('active');
    document.getElementById('prevBtn').style.display = n === 0 ? 'none' : 'inline-block';
    document.getElementById('nextBtn').style.display = n === totalSections - 1 ? 'none' : 'inline-block';
    document.getElementById('submitBtn').style.display = n === totalSections - 1 ? 'inline-block' : 'none';
    updateProgress();
}

function changeSection(n) {
    const newSection = currentSection + n;
    if (newSection >= 0 && newSection < totalSections) {
        if (n > 0 && !validateSection(currentSection)) return;
        currentSection = newSection;
        showSection(currentSection);
    }
}

function validateSection(sectionNum) {
    // Aquí puedes añadir validación si lo deseas
    // Por ejemplo, verificar que todas las preguntas tienen respuesta
    return true;
}

function submitSurvey() {
    const formData = new FormData(document.getElementById('surveyForm'));
    const responses = {};
    for (let [key, value] of formData.entries()) {
        responses[key] = value;
    }
    
    // Debug: muestra en consola lo que se va a enviar
    console.log("Datos a enviar:", responses);
    
    // Enviar a Google Sheets
    fetch(GOOGLE_SHEET_URL, {
        method: 'POST',
        mode: 'no-cors',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(responses)
    }).then(() => {
        console.log("Datos enviados correctamente");
        
        // También guardar en localStorage para análisis local
        surveyData.push(responses);
        localStorage.setItem('surveyData', JSON.stringify(surveyData));
        updateParticipantCounter();
        
        // Actualizar la interfaz
        document.getElementById('resultsSection').classList.add('show');
        document.getElementById('surveyForm').style.display = 'none';
        document.querySelector('.navigation-buttons').style.display = 'none';
        window.scrollTo(0,0);
    }).catch(error => {
        console.error("Error al enviar datos:", error);
        alert("Ha ocurrido un error al enviar tus respuestas. Por favor intenta nuevamente.");
    });
}

function resetSurvey() {
    document.getElementById('surveyForm').reset();
    document.getElementById('surveyForm').style.display = '';
    document.querySelector('.navigation-buttons').style.display = '';
    document.getElementById('resultsSection').classList.remove('show');
    showSection(0);
    currentSection = 0;
    updateProgress();
}

function exportData() {
    let data = surveyData;
    if (!data.length) { alert("No hay datos para exportar."); return; }
    const keys = Array.from(data.reduce((a, b) => {
        Object.keys(b).forEach(k => a.add(k));
        return a;
    }, new Set()));
    let csv = keys.join(",") + "\n";
    data.forEach(row => {
        csv += keys.map(k => `"${(row[k] || '').replace(/"/g, '""')}"`).join(",") + "\n";
    });
    const blob = new Blob([csv], {type: "text/csv"});
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = "resultados_encuesta.csv";
    a.click();
    URL.revokeObjectURL(url);
}

function viewResults() {
    let data = surveyData;
    if (!data.length) { alert("No hay datos para mostrar."); return; }
    let html = "<table class='survey-table'><thead><tr>";
    const keys = Array.from(data.reduce((a, b) => {
        Object.keys(b).forEach(k => a.add(k));
        return a;
    }, new Set()));
    keys.forEach(k => html += `<th>${k}</th>`);
    html += "</tr></thead><tbody>";
    data.forEach(row => {
        html += "<tr>";
        keys.forEach(k => html += `<td>${row[k] || ""}</td>`);
        html += "</tr>";
    });
    html += "</tbody></table>";
    document.getElementById("analysisTables").innerHTML = html;
    document.getElementById("analysisSection").classList.add("show");
    document.getElementById("resultsSection").classList.remove("show");
    renderCharts();
}

function closeAnalysis() {
    document.getElementById("analysisSection").classList.remove("show");
    document.getElementById("resultsSection").classList.add("show");
}

function generateAnalysis() {
    let data = surveyData;
    if (!data.length) { alert("No hay datos para analizar."); return; }
    let html = "";
    let ageGroups = {}, genders = {};
    data.forEach(d=>{
        ageGroups[d.age] = (ageGroups[d.age]||0)+1;
        genders[d.gender] = (genders[d.gender]||0)+1;
    });
    html += "<div style='margin-bottom:25px'><strong>Distribución de Edad</strong><table class='survey-table'><thead><tr><th>Edad</th><th>Conteo</th></tr></thead><tbody>";
    Object.entries(ageGroups).forEach(([k,v])=>{ html += `<tr><td>${k}</td><td>${v}</td></tr>`; });
    html += "</tbody></table></div>";
    html += "<div style='margin-bottom:25px'><strong>Distribución de Género</strong><table class='survey-table'><thead><tr><th>Género</th><th>Conteo</th></tr></thead><tbody>";
    Object.entries(genders).forEach(([k,v])=>{ html += `<tr><td>${k}</td><td>${v}</td></tr>`; });
    html += "</tbody></table></div>";

    for(let i=1; i<=8; i++) {
        let q = {};
        data.forEach(d=>{q[d[`q${i}`]]=(q[d[`q${i}`]]||0)+1;});
        html += `<div style='margin-bottom:25px'><strong>Pregunta ${i}</strong><table class='survey-table'><thead><tr><th>Puntuación</th><th>Conteo</th></tr></thead><tbody>`;
        Object.entries(q).forEach(([k,v])=>{ html += `<tr><td>${k||'-'}</td><td>${v}</td></tr>`; });
        html += "</tbody></table></div>";
    }

    document.getElementById("analysisTables").innerHTML = html;
    document.getElementById("analysisSection").classList.add("show");
    document.getElementById("resultsSection").classList.remove("show");
    renderCharts();
}

let chartInstances = [];
function renderCharts() {
    chartInstances.forEach(c => c.destroy && c.destroy());
    chartInstances = [];
    let data = surveyData;
    let ageGroups = {};
    data.forEach(d=>{ageGroups[d.age]= (ageGroups[d.age]||0)+1;});
    let ageLabels = Object.keys(ageGroups), ageCounts = Object.values(ageGroups);
    let genders = {};
    data.forEach(d=>{genders[d.gender]=(genders[d.gender]||0)+1;});
    let genderLabels = Object.keys(genders), genderCounts = Object.values(genders);

    const html = `
        <div class="chart-box"><div class="chart-title">Distribución por Edad</div><canvas id="ageBar"></canvas></div>
        <div class="chart-box"><div class="chart-title">Distribución por Género</div><canvas id="genderPie"></canvas></div>
    `;
    document.getElementById("chartsContainer").innerHTML = html;

    chartInstances.push(new Chart(document.getElementById('ageBar').getContext('2d'), {
        type: 'bar',
        data: {
            labels: ageLabels,
            datasets: [{label: 'Participantes', data: ageCounts, backgroundColor: '#ffa94d'}]
        },
        options: {responsive:true, plugins:{legend:{display:false}}}
    }));
    chartInstances.push(new Chart(document.getElementById('genderPie').getContext('2d'), {
        type: 'pie',
        data: {
            labels: genderLabels,
            datasets: [{ data: genderCounts, backgroundColor: ['#ffb661','#e18d5a','#ffbe76','#ffe2c6','#ffa94d','#b3b3b3'] }]
        },
        options: {responsive:true}
    }));
}

showSection(0);
document.addEventListener("DOMContentLoaded", updateParticipantCounter);
document.getElementById('surveyForm').addEventListener('submit', e => e.preventDefault());
