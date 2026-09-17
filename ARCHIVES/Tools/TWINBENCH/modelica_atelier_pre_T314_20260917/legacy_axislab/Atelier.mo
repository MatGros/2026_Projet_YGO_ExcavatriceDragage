within ;
package Atelier "Jumeau d'etude M1-M2-M3, non calibre et sans PLC"
  connector Signal = input Real;
  connector Result = output Real;

  model Drive "Entrainement M3 reduit a un effort limite"
    Signal lever;
    Signal held;
    Signal forceLimit;
    Result force(start=0, fixed=true);
  equation
    der(force) = ((if held > 0.5 then max(-1,min(1,lever))*forceLimit else 0)-force)/0.18;
  end Drive;

  model Carriage "Translation M3 : masse, trainee et frein"
    Signal force;
    Signal held;
    Signal mass;
    Signal brakeDelay;
    Result position(start=12,fixed=true);
    Result velocity(start=0,fixed=true);
    Real brake(start=1,fixed=true);
    Real acceleration;
    Real brakeForce;
  equation
    der(brake)=((if held > 0.5 then 0 else 1)-brake)/max(0.02,brakeDelay);
    brakeForce=brake*12000*tanh(velocity/0.08);
    acceleration=(force-1600*velocity-brakeForce)/max(100,mass);
    der(velocity)=acceleration;
    der(position)=velocity;
  end Carriage;

  model Winch "Treuil cable : vitesse filtree et frein; signe + = montee"
    Signal command;
    Signal held;
    Signal maxSpeed;
    Result cablePosition(start=8.5,fixed=true);
    Result cableSpeed(start=0,fixed=true);
  equation
    der(cableSpeed)=((if held > 0.5 then max(-1,min(1,command))*maxSpeed else 0)-cableSpeed)/0.16;
    der(cablePosition)=cableSpeed;
  end Winch;

  model AxisLab "DredgeLab M1 retenue, M2 benne, M3 translation"
    input Real lever=0 "Commande M3 translation [-1,1]";
    input Real m1Command=0 "Commande M1 retenue [-1,1], + montee";
    input Real m2Command=0 "Commande M2 benne [-1,1], + montee";
    input Real held=0 "Homme-mort commun [0,1]";
    input Real mass=4000 "Masse mobile M3 kg";
    input Real forceLimit=3500 "Effort moteur M3 maximal N";
    input Real brakeDelay=0.25 "Constante de temps frein M3 s";
    input Real sensorPosition=21 "Position capteur M3 m";
    input Real winchMaxSpeed=0.65 "Vitesse cable maximale M1/M2 m/s";
    input Real translationMinHeight=6 "Hauteur M1 et M2 minimale pour M3 m";
    input Real bucketOffsetOpen=0 "Delta M2-M1 benne ouverte m";
    input Real bucketOffsetClose=15 "Delta M2-M1 benne fermee m";
    Drive m3Drive;
    Carriage carriage;
    Winch m1;
    Winch m2;
    output Real position "Position M3";
    output Real velocity "Vitesse M3";
    output Real acceleration;
    output Real motorForce;
    output Real brakeForce;
    output Real brake;
    output Real sensor;
    output Real energy;
    output Real overtravel;
    output Real m1Position "Position cable M1";
    output Real m1Speed;
    output Real m2Position "Position cable M2";
    output Real m2Speed;
    output Real bucketDelta "Delta cable M2-M1";
    output Real bucketOpening "Ouverture benne 0..100 %";
    output Real bucketOpen;
    output Real bucketClosed;
    output Real translationPermit;
  equation
    // Convention machine documentee : M1 = retenue, M2 = benne, signe + = montee.
    // Delta M2-M1 = 0 m ouverte, 15 m fermee (GVL_PERSISTENT).
    m1.command=m1Command;
    m1.held=held;
    m1.maxSpeed=winchMaxSpeed;
    m2.command=m2Command;
    m2.held=held;
    m2.maxSpeed=winchMaxSpeed;
    translationPermit=if m1.cablePosition>=translationMinHeight and m2.cablePosition>=translationMinHeight then 1 else 0;
    m3Drive.lever=if translationPermit>0.5 then lever else 0;
    m3Drive.held=held;
    m3Drive.forceLimit=forceLimit;
    connect(m3Drive.force,carriage.force);
    carriage.held=held;
    carriage.mass=mass;
    carriage.brakeDelay=brakeDelay;
    position=carriage.position;
    velocity=carriage.velocity;
    acceleration=carriage.acceleration;
    motorForce=m3Drive.force;
    brakeForce=carriage.brakeForce;
    brake=carriage.brake;
    sensor=if abs(position-sensorPosition)<0.35 then 1 else 0;
    energy=0.5*mass*velocity*velocity;
    overtravel=if position<0 or position>30 then 1 else 0;
    m1Position=m1.cablePosition;
    m1Speed=m1.cableSpeed;
    m2Position=m2.cablePosition;
    m2Speed=m2.cableSpeed;
    bucketDelta=m2.cablePosition-m1.cablePosition;
    bucketOpening=100*max(0,min(1,(bucketOffsetClose-bucketDelta)/max(0.1,bucketOffsetClose-bucketOffsetOpen)));
    bucketOpen=if bucketOpening>=95 then 1 else 0;
    bucketClosed=if bucketOpening<=5 then 1 else 0;
    annotation(experiment(StartTime=0,StopTime=30,Tolerance=1e-6,Interval=0.02),Documentation(info="<html><p>Modele de premier niveau fonde sur les conventions projet : M1 retenue, M2 benne, M3 translation ; delta M2-M1 = 0 m ouverte et 15 m fermee ; translation autorisee seulement si M1 et M2 sont au-dessus de 6 m. Les vitesses de cable et la geometrie de mouflage sont des hypotheses de POC, non une caracterisation machine.</p></html>"));
  end AxisLab;

  package Examples "Exemples directement simulables dans OMEdit"
    model CycleM1M2M3 "Cycle guide : levage, translation, fermeture et ouverture"
      AxisLab machine(
        held=if time < 2 or time >= 72 then 0 else 1,
        m1Command=if time >= 2 and time < 7 then 0.5 else 0,
        m2Command=if time >= 2 and time < 7 then 0.5 else
                  if time >= 15 and time < 40 then 1 else
                  if time >= 40 and time < 65 then -1 else 0,
        lever=if time >= 7 and time < 15 then 0.7 else
              if time >= 65 and time < 72 then -0.7 else 0);
      annotation(
        experiment(StartTime=0, StopTime=75, Tolerance=1e-6, Interval=0.02),
        Documentation(info="<html><p>Exemple autonome pour OMEdit. Simuler cette classe puis tracer machine.position, machine.m1Position, machine.m2Position, machine.bucketOpening et machine.held.</p><p>Ce cycle sert a apprendre le workflow et ne constitue pas un cycle machine valide.</p></html>"));
    end CycleM1M2M3;

    model AnimatedCycle "Vue 3D simple du cycle M1-M2-M3 dans OMEdit"
      extends CycleM1M2M3;
      import Shape = Modelica.Mechanics.MultiBody.Visualizers.Advanced.Shape;

      Shape water(
        shapeType="box", r={0,-3,0}, length=30, width=6, height=0.2,
        color={35,120,170});
      Shape rail(
        shapeType="box", r={0,-0.4,20}, length=30, width=0.8, height=0.5,
        color={75,85,95});
      Shape carriage(
        shapeType="box", r={machine.position - 0.75,-1,19.6},
        length=1.5, width=2, height=0.9, color={225,155,35});
      Shape m1Cable(
        shapeType="cylinder", r={machine.position - 0.3,-0.25,machine.m1Position},
        lengthDirection={0,0,1}, widthDirection={1,0,0},
        length=max(0.05,20 - machine.m1Position), width=0.07, height=0.07,
        color={45,45,50});
      Shape m2Cable(
        shapeType="cylinder", r={machine.position + 0.3,0.25,machine.m1Position},
        lengthDirection={0,0,1}, widthDirection={1,0,0},
        length=max(0.05,20 - machine.m1Position), width=0.07, height=0.07,
        color={80,80,85});
      Shape bucketBridge(
        shapeType="box", r={machine.position - 0.8,-0.75,machine.m1Position - 0.35},
        length=1.6, width=1.5, height=0.35, color={120,80,45});
      Shape leftJaw(
        shapeType="box",
        r={machine.position - 0.9 - 0.008*machine.bucketOpening,-0.65,machine.m1Position - 1.85},
        length=0.9, width=1.3, height=1.5, color={145,90,45});
      Shape rightJaw(
        shapeType="box",
        r={machine.position + 0.008*machine.bucketOpening,-0.65,machine.m1Position - 1.85},
        length=0.9, width=1.3, height=1.5, color={145,90,45});
      annotation(
        experiment(StartTime=0, StopTime=75, Tolerance=1e-6, Interval=0.02),
        Documentation(info="<html><p>Vue 3D pedagogique : rail, chariot M3, cables, traverse et deux machoires. Elle est volontairement schematique et ne represente pas encore la geometrie ni le mouflage reels.</p><p>Dans OMEdit, choisir Simuler avec animation.</p></html>"));
    end AnimatedCycle;
  end Examples;
  annotation(uses(Modelica(version="4.0.0")));
end Atelier;
