# -*- coding: utf-8 -*-
import time, os, io, hashlib
project_dir=r"C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/TOOLS/AGENT_WORKFLOW/.tmp/t417_m3_t423_run_r8_20261101"
project_file=None
logfile=r"C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/TOOLS/AGENT_WORKFLOW/.tmp/t417_m3_t423_run_r8_20261101/runtime.log"
csvfile=r"C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/TOOLS/AGENT_WORKFLOW/.tmp/t417_m3_t423_run_r8_20261101/samples.csv"
MASTER="GVL_Simulation.SimulationModeActive"
SIM_M3="GVL_Simulation.SimTranslationActive"
BTN_RIGHT="GVL_Simulation.SimJoystickRight_Fwd_MAINT_Active"
BTN_LEFT="GVL_Simulation.SimJoystickLeft_Rev_TREMIE_Active"
SEL_MODE="GVL_IHM.Modes.Cmd.SelMode"
SET_FREQ="GVL_IHM.M3Translation.Cmd.SetFreq_Hz"
SIM_CHAIN="GVL_Simulation.SimChainOk"
ARM_BUTTON="GVL_IHM.Emergency.Cmd.BtnEmergencyArming"
SAFETY_CHAIN_OK="GVL_IHM.Emergency.State.ChainOk"
SAFETY_ARMABLE="GVL_IHM.Emergency.State.Armable"
SAFETY_CONTACTOR_OK="GVL_IHM.Emergency.State.ContactorOk"
SAFETY_BUSY="GVL_IHM.Emergency.State.ArmingBusy"
SAFETY_FAULT="GVL_IHM.Emergency.State.Fault.Error"
SAFETY_LATCHED="GVL_IHM.Emergency.State.Fault.Latched"
FAULT_ID="GVL_IHM.Emergency.State.Fault.ErrorId"
LATCHED_ID="GVL_IHM.Emergency.State.Fault.LatchedId"
RESET_BUTTON="GVL_IHM.Modes.Cmd.BtnFaultReset"
SAFETY_DONE="GVL_IHM.Emergency.State.Done"
SAFETY_STEP="GVL_IHM.Emergency.State.Step"
SAFETY_ARM_PULSE="GVL_IHM.Emergency.State.ArmPulse_Cmd"
EMERGENCY_CUTOFF="GVL_IHM.Emergency.Cmd.BtnEmergencyCutOff"
PATHS=(
 MASTER, SIM_M3,
 "GVL_Simulation.SimM3ObsPositionTrue_M",
 "GVL_Simulation.SimM3ObsPositionError_M",
 "GVL_Simulation.SimM3ObsOvershootLast_M",
 "GVL_Simulation.SimM3ObsOvershootSensorId",
 "GVL_Simulation.SimM3ObsEndStopHitCount",
 "GVL_Simulation.SimM3ObsEndStopImpactSpeed_Mps",
 "GVL_Simulation.SimM3ObsBrakeClosedMovingCount",
 "GVL_Simulation.SimJoystickRight_Fwd_MAINT_Active",
 "GVL_Simulation.SimJoystickLeft_Rev_TREMIE_Active",
 "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx101_PosTremie_DI",
 "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx104_PosP1_DI",
 "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx106_DriveActualFreq_Hz",
 "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx108_BrakeApplied",
 "GVL_IHM.IoHw.Out.M3_CommandWord",
 "GVL_Troubleshooting.P_MotionM3.Step1_PowerEngaged",
 "GVL_Troubleshooting.P_MotionM3.Step2_ModeAuthorized",
 "GVL_Troubleshooting.P_MotionM3.Step4_MotionRequested",
 "GVL_Troubleshooting.P_MotionM3.Step5_NoSafetyFault",
 "GVL_Troubleshooting.P_MotionM3.Step6_DirectionAllowed",
 "GVL_Troubleshooting.P_MotionM3.Step7_BrakeReleased",
 "GVL_Troubleshooting.P_MotionM3.RequestedDirection",
 "GVL_Troubleshooting.P_MotionM3.RequestedSpeedPct",
 "GVL_IHM.Modes.State.CurrentMode",
 "GVL_IHM.Modes.Cmd.TglJoystickMaster",
 "GVL_IHM.Permits.ArmingPermit",
 "GVL_IHM.JOY1Joystick.State.DeadmanArmed",
 "GVL_IHM.JOY1Joystick.State.RawX",
 "GVL_IHM.JOY1Joystick.State.RawButton",
 SET_FREQ,
 "GVL_PERSISTENT._TranslationPosTremie_M",
 "GVL_PERSISTENT._TranslationPosP1_M",
 "PRG_02_Acquisition.instSimBench.SimM3SpeedFactor",
 SIM_CHAIN, ARM_BUTTON, SAFETY_CHAIN_OK, SAFETY_ARMABLE,
 SAFETY_CONTACTOR_OK, SAFETY_BUSY, SAFETY_FAULT, SAFETY_DONE,
 SAFETY_STEP, SAFETY_ARM_PULSE, EMERGENCY_CUTOFF, SAFETY_LATCHED, FAULT_ID, LATCHED_ID, RESET_BUTTON,
 "GVL_Simulation.SimSafetyActive", "PRG_06_Outputs.Data.PowerCutOffRequest", "PRG_06_Outputs.Data.TestCutActive", "PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI",
 "PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.PowerCutOff", "PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.PowerCutOff", "PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerCutOff",
)
def log(s):
 f=open(logfile,"a"); f.write(str(s)+"\n"); f.close()
def b(v):
 s=str(v).strip().upper()
 if s in ("TRUE","1","BOOL#TRUE"): return True
 if s in ("FALSE","0","BOOL#FALSE"): return False
 raise Exception("unreadable boolean value: "+str(v))
def n(v):
 s=str(v).strip()
 if "#" in s: s=s.split("#",1)[1]
 try: return float(s)
 except: raise Exception("unreadable numeric value: "+str(v))
def wordbits(v):
 s=str(v).strip().upper().split("#")
 try:
  if len(s)>=3 and s[-2]=="16": return int(s[-1],16)
  return int(s[-1],10)
 except: raise Exception("unreadable word value: "+str(v))
def read(oa):
 v=list(oa.read_values(PATHS))
 if len(v)!=len(PATHS): raise Exception("batch read length mismatch")
 return dict(zip(PATHS,v))
def write(oa,path,value):
 oa.set_prepared_value(path,str(value))
 oa.write_prepared_values()
def write_bool(oa,path,value): write(oa,path,"TRUE" if value else "FALSE")
def force_value(oa,path,value):
 oa.set_prepared_value(path,str(value))
 for m in ("force_prepared_values","ForcePreparedValues","force_values"):
  if hasattr(oa,m): getattr(oa,m)(); return True
 return False
def enum_name(raw):
 s=str(raw)
 if "#" in s: s=s.split("#",1)[1]
 if "." in s: s=s.split(".")[-1]
 return s.strip()
def snapshot(oa,stream,label,leg):
 d=read(oa); now=time.time()
 fields=("%.3f"%now,label,leg,d[PATHS[2]],d[PATHS[3]],d[PATHS[4]],d[PATHS[5]],d[PATHS[11]],d[PATHS[12]],d[PATHS[13]],d[PATHS[14]],d[PATHS[15]],d[PATHS[16]],d[PATHS[17]],d[PATHS[18]],d[PATHS[19]],d[PATHS[20]],d[PATHS[21]],d[PATHS[22]],d[PATHS[23]],d[PATHS[24]],d[PATHS[25]],d[PATHS[26]],d[PATHS[27]],d[PATHS[28]],d[PATHS[29]],d[PATHS[30]],d[PATHS[31]],d[PATHS[32]],d[PATHS[33]])
 stream.write(",".join([str(x).replace(",",";") for x in fields])+"\n"); stream.flush()
 return d
p=None; oa=None; stream=None; master_written=False; chain_written=False; arm_command_written=False; reset_command_written=False; mode_changed=False; freq_changed=False; input_button=None; original_mode=None; original_freq=None
try:
 stream=open(csvfile,"w")
 stream.write("epoch_s,label,leg,pos_true_m,pos_error_m,overshoot_m,overshoot_sensor_id,pos_tremie,pos_p1,actual_freq_hz,brake_applied,cmd_word,power_engaged,mode_authorized,motion_requested,no_safety_fault,direction_allowed,brake_released,requested_direction,requested_speed_pct,current_mode,joystick_master,arming_permit,deadman_armed,raw_x,raw_button,set_freq_hz,pos_tremie_cfg_m,pos_p1_cfg_m,speed_factor\n")
 project_file=next(os.path.join(project_dir,x) for x in os.listdir(project_dir) if x.lower().endswith(".project"))
 log("project_file="+project_file)
 p=projects.open(project_file,primary=True,update_flags=VersionUpdateFlags.NoUpdates)
 app=p.active_application
 dev=app
 while dev is not None and not hasattr(dev,"set_simulation_mode"): dev=dev.parent
 if dev is None: raise Exception("Device missing")
 did=str(dev.get_device_identification()); log("device_id="+did)
 if did.find("4097")<0 or did.find("0000 000a")<0: raise Exception("unexpected target; refusing online operations: "+did)
 dev.set_simulation_mode(True)
 if not dev.get_simulation_mode(): raise Exception("Simulation IDE not confirmed")
 log("simulation_mode=True")
 log("BASELINE: build result and online source identity must be verified before model verdict")
 for name,rel in [("FB_Sim_Translation","CODE/L_SIMULATION/FB_Sim_Translation.st"),("FB_Hmi_BannerFormatter","CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st"),("PRG_07_Supervision","CODE/M_MAIN/PRG_07_Supervision.st"),("FB_CycleSemiAuto","CODE/G_CYCLE/FB_CycleSemiAuto.st")]:
  content=io.open('C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage'+"/"+rel,"r",encoding="utf-8").read()
  log("SOURCE_SHA256="+name+" "+hashlib.sha256(content.encode("utf-8")).hexdigest())
  objs=p.find(name,True)
  if not objs: raise Exception("object missing "+name)
  for i,obj in enumerate(objs):
   parent=getattr(obj,"parent",None); log("CANDIDATE="+name+" index="+str(i)+" object="+str(obj)+" parent="+str(parent)+" textual="+str(hasattr(obj,"textual_declaration")))
  objs=[obj for obj in objs if hasattr(obj,"textual_declaration") and hasattr(obj,"textual_implementation")]
  if len(objs)!=1: raise Exception("textual POU count for "+name+" = "+str(len(objs)))
  log("SELECTED_TEXTUAL="+name)
  pos=content.rfind("END_VAR")
  if pos<0: raise Exception("missing END_VAR "+name)
  decl=content[:pos+7]; impl=content[pos+7:].strip()
  for term in ("END_PROGRAM","END_FUNCTION_BLOCK"):
   if impl.endswith(term): impl=impl[:-len(term)].rstrip()
  objs[0].textual_declaration.replace(decl); objs[0].textual_implementation.replace(impl)
  log("UPDATED="+name)
 for c in system.get_message_categories(False): system.clear_messages(c)
 app.rebuild()
 msgs=[]
 for c in system.get_message_categories(True): msgs.extend(system.get_message_objects(c))
 errors=[m for m in msgs if m.severity==Severity.Error or m.severity==Severity.FatalError]
 for m in errors: log("BUILD_ERROR="+str(m.text))
 log("BUILD_ERRORS="+str(len(errors)))
 if errors: raise Exception("BUILD_FAILED_ABORT_BEFORE_LOGIN: runtime execution forbidden")
 online.auth_fallback_modes=CredentialSourceKind.CurrentProjectSession
 oa=online.create_online_application(app)
 oa.login(OnlineChangeOption.Try,True)
 if not oa.is_logged_in: raise Exception("login not confirmed")
 log("login=True app_state="+str(oa.application_state)+" operation="+str(oa.operation_state))
 d=read(oa)
 original_mode=enum_name(d[PATHS[24]])
 original_freq=n(d[PATHS[30]])
 log("initial_mode="+original_mode+" initial_set_freq_hz="+str(original_freq)+" initial="+str(d))
 if oa.application_state!=ApplicationState.stop: raise Exception("application not STOP before start")
 if b(d[MASTER]) or b(d[SIM_M3]): raise Exception("simulation flags not FALSE before start")
 if b(d[PATHS[9]]) or b(d[PATHS[10]]): raise Exception("simulated joystick stimulus active before start")
 if n(d[PATHS[13]])!=0.0 or str(d[PATHS[15]]).strip() not in ("WORD#0","0"): raise Exception("M3 command/feedback not zero before start")
 oa.start()
 if oa.application_state!=ApplicationState.run: raise Exception("application did not enter RUN")
 log("application_state=run")
 time.sleep(0.5)
 d=snapshot(oa,stream,"RUN_IDLE","none")
 if b(d[MASTER]) or b(d[SIM_M3]): raise Exception("simulation master unexpectedly active before test")
 if n(d[PATHS[13]])!=0.0 or str(d[PATHS[15]]).strip() not in ("WORD#0","0"): raise Exception("unexpected motion in idle")
 write_bool(oa,MASTER,True); master_written=True
 deadline=time.time()+3.0
 while time.time()<deadline:
  d=snapshot(oa,stream,"ARM_SIM","none")
  if b(d[MASTER]) and b(d[SIM_M3]): break
  time.sleep(0.1)
 else: raise Exception("simulation gates did not become TRUE")
 log("simulation_gates_confirmed=True pos="+str(d[PATHS[2]])+" p1="+str(d[PATHS[12]])+" tremie="+str(d[PATHS[11]]))
 if not b(d[PATHS[25]]): raise Exception("joystick master not selected; refusing joystick simulation input")
 if b(d[PATHS[9]]) or b(d[PATHS[10]]) or b(d[SIM_CHAIN]): raise Exception("unexpected simulated direction or safety-chain input before arming")
 if b(d[EMERGENCY_CUTOFF]) or b(d[SAFETY_CONTACTOR_OK]) or b(d[RESET_BUTTON]): raise Exception("cutoff, contactor or reset unexpectedly active")
 log("fault_before_chain="+str({k:d[k] for k in (SAFETY_FAULT,SAFETY_LATCHED,FAULT_ID,LATCHED_ID)}))
 # Same simulation, encoder-health and safety flags as T423 rearm_emergency().
 for q,v in [("GVL_Simulation.SimWinchActive","TRUE"),("GVL_Simulation.SimTranslationActive","TRUE"),("GVL_Simulation.SimSafetyActive","TRUE"),("GVL_Simulation.SimChainOk","TRUE"),("GVL_Simulation.SimPhaseRotationOk","TRUE"),("PRG_02_Acquisition.instDiagEthercat.DeviceEncoderM1.Operational","TRUE"),("PRG_02_Acquisition.instDiagEthercat.DeviceEncoderM2.Operational","TRUE"),("PRG_02_Acquisition.instDiagEthercat.DeviceVariateur.Operational","TRUE"),("GVL_IHM.Network.Bypass.Global","FALSE")]: write(oa,q,v)
 chain_written=True
 # T423 rearm order: chain/simulation ready -> reset -> explicit arming pulse -> wait.
 time.sleep(0.1)
 d=read(oa); live=wordbits(d[FAULT_ID]); latched=wordbits(d[LATCHED_ID])
 log("fault_before_T423_reset="+str({k:d[k] for k in (SAFETY_FAULT,SAFETY_LATCHED,FAULT_ID,LATCHED_ID)}))
 if live|latched:
  if ((live|latched)&~8)!=0: raise Exception("non-startup fault; no acknowledgement: live="+str(live)+" latched="+str(latched))
  write_bool(oa,RESET_BUTTON,True); reset_command_written=True; time.sleep(0.2)
  write_bool(oa,RESET_BUTTON,False); reset_command_written=False; time.sleep(0.3)
  log("T423_fault_reset_pulsed=True")
 deadline=time.time()+5.0
 while time.time()<deadline:
  d=snapshot(oa,stream,"T423_CHAIN_READY","none")
  if b(d[EMERGENCY_CUTOFF]): raise Exception("emergency cutoff active")
  if b(d[SAFETY_CHAIN_OK]) and b(d[SAFETY_ARMABLE]) and not b(d[SAFETY_BUSY]): break
  time.sleep(0.1)
 else: raise Exception("T423 chain/armable not confirmed: "+str({k:d[k] for k in (SIM_CHAIN,SAFETY_CHAIN_OK,SAFETY_ARMABLE,SAFETY_CONTACTOR_OK,SAFETY_BUSY,SAFETY_FAULT,FAULT_ID,LATCHED_ID)}))
 log("T423_chain_ready="+str({k:d[k] for k in (SAFETY_CHAIN_OK,SAFETY_ARMABLE,SAFETY_CONTACTOR_OK,SAFETY_BUSY,SAFETY_FAULT,SAFETY_STEP)}))
 write_bool(oa,ARM_BUTTON,True); arm_command_written=True; time.sleep(0.5)
 write_bool(oa,ARM_BUTTON,False); arm_command_written=False; time.sleep(4.5)
 d=read(oa)
 if b(d[SAFETY_FAULT]) or b(d[SAFETY_LATCHED]) or not b(d[SAFETY_CONTACTOR_OK]) or not b(d[SAFETY_DONE]): raise Exception("T423 arm not confirmed: "+str({k:d[k] for k in (SAFETY_CHAIN_OK,SAFETY_CONTACTOR_OK,SAFETY_FAULT,SAFETY_LATCHED,SAFETY_DONE,SAFETY_STEP)}))
 log("T423_safety_rearm_confirmed=True")
 # T423 reference setup: neutral operator + simulation encoder health + homed state.
 for q,v in [("GVL_IHM.Modes.Cmd.SelMode","1"),("GVL_IHM.Modes.Cmd.SelJoystickWinch","0"),("GVL_Simulation.SimJoystickRawButton","FALSE"),("GVL_IHM.Network.Bypass.Global","FALSE"),("PRG_02_Acquisition.instDiagEthercat.DeviceEncoderM1.Operational","TRUE"),("PRG_02_Acquisition.instDiagEthercat.DeviceEncoderM2.Operational","TRUE"),("PRG_02_Acquisition.instDiagEthercat.DeviceVariateur.Operational","TRUE")]: write(oa,q,v)
 hpaths=["PRG_02_Acquisition.instCycleMachineHoming.MachineHomingStep","PRG_02_Acquisition.instCycleMachineHoming.MachineHomed","PRG_02_Acquisition.Data.MachineHoming.Step","PRG_02_Acquisition.Data.MachineHoming.Homed"]
 hbefore=dict((q,oa.read_value(q)) for q in hpaths); log("homing_before_T423_setup="+str(hbefore))
 for q,v in zip(hpaths,("60","TRUE","60","TRUE")):
  if not force_value(oa,q,v): raise Exception("CODESYS force API missing for "+q)
 time.sleep(6.5)
 hafter=dict((q,oa.read_value(q)) for q in hpaths); log("homing_after_T423_setup="+str(hafter))
 for q in hpaths:
  hv=str(hafter[q]).strip().upper()
  if q.endswith("MachineHomingStep"):
   if hv not in ("60","DINT#60","INT#60") and hv.split(".")[-1] != "VALID": raise Exception("homing step not valid: "+q+"="+hv)
  elif q.endswith("Homed"):
   if hv not in ("TRUE","BOOL#TRUE","1"): raise Exception("homing not confirmed: "+q+"="+hv)
  elif hv not in ("60","DINT#60","INT#60"): raise Exception("homing step not valid: "+q+"="+hv)
 d=read(oa)
 log("T423_homing_setup_confirmed=True")
 # Dedicated simulation-only height bypass: M1/M2 encoder heights remain below the 6 m collision threshold.
 min_bypass_before=str(oa.read_value("GVL_IHM.M3Translation.Bypass.MinHeight"))
 write_bool(oa,"GVL_IHM.M3Translation.Bypass.MinHeight",True); time.sleep(0.2)
 height_ok=str(oa.read_value("PRG_05_Translation.M3_HeightInterlockOk")).strip().upper()
 log("simulation_MinHeight_bypass_before="+min_bypass_before+" height_interlock_ok="+height_ok)
 if height_ok not in ("TRUE","BOOL#TRUE"): raise Exception("dedicated simulation height bypass not accepted")
 original_mode=enum_name(d[PATHS[24]])
 original_freq=n(d[PATHS[30]])
 write(oa,SEL_MODE,"1"); mode_changed=True
 write(oa,SET_FREQ,"10.0"); freq_changed=True
 deadline=time.time()+4.0
 while time.time()<deadline:
  d=snapshot(oa,stream,"ARM_MANUAL","none")
  if enum_name(d[PATHS[24]])=="MAINT_N1" and b(d[PATHS[26]]) and b(d[PATHS[16]]) and b(d[PATHS[19]]): break
  time.sleep(0.1)
 else: raise Exception("MAINT_N1 or arming/safety prerequisites not confirmed: "+str(d))
 if abs(n(d[PATHS[30]])-10.0)>0.001: raise Exception("10Hz setpoint was not accepted: "+str(d[PATHS[30]]))
 if n(d[PATHS[28]])!=5000.0 or b(d[PATHS[29]]) or b(d[PATHS[27]]): raise Exception("joystick did not return to neutral/unarmed before movement: "+str({"raw_x":d[PATHS[28]],"raw_button":d[PATHS[29]],"deadman_armed":d[PATHS[27]]}))
 if not b(d[SAFETY_CONTACTOR_OK]) or b(d[SAFETY_FAULT]) or b(d[SAFETY_LATCHED]) or b(d[EMERGENCY_CUTOFF]): raise Exception("safety preconditions lost before movement")
 log("manual_prerequisites_confirmed="+str({"mode":d[PATHS[24]],"arming":d[PATHS[26]],"power":d[PATHS[16]],"safe":d[PATHS[19]],"joystick_master":d[PATHS[25]],"set_freq":d[PATHS[30]],"speed_factor":d[PATHS[33]],"tremie_cfg":d[PATHS[31]],"p1_cfg":d[PATHS[32]],"raw_x":d[PATHS[28]],"raw_button":d[PATHS[29]],"deadman_armed":d[PATHS[27]],"contactor_ok":d[SAFETY_CONTACTOR_OK]}))
 POSITION_TOLERANCE_M=0.025  # 0.020 m capteur + 0.004 m au plus a 20 Hz/10 ms, arrondi au mm.
 def at_target(d,target_path):
  pos=n(d[PATHS[2]])
  if target_path==PATHS[12]: return abs(pos-n(d[PATHS[32]]))<=POSITION_TOLERANCE_M
  return b(d[target_path]) and pos<=n(d[PATHS[31]])+POSITION_TOLERANCE_M
 def leg(name,stimulus,target_path,expected_sign,nominal_hz,timeout_s):
  global input_button
  before=read(oa); start_pos=n(before[PATHS[2]])
  if at_target(before,target_path):
   log("LEG_SKIP already_at_physical_target="+name+" pos="+str(start_pos))
   return {"skipped":True,"start":start_pos,"finish":start_pos,"overshoot":before[PATHS[4]],"sensor_id":before[PATHS[5]],"sensor_elapsed":0.0,"stop_elapsed":0.0,"max_freq":n(before[PATHS[13]])}
  write_bool(oa,stimulus,True); input_button=stimulus
  t0=time.time(); deadline=t0+timeout_s; last=start_pos; moved=False; target=False; maxfreq=0.0; sensor_elapsed=None; sensor_pos=None
  while time.time()<deadline:
   d=snapshot(oa,stream,"MOVE",name); pos=n(d[PATHS[2]]); freq=n(d[PATHS[13]])
   if freq>maxfreq: maxfreq=freq
   if abs(pos-start_pos)>0.005 or freq>0.0: moved=True
   if expected_sign>0 and pos<last-0.03: raise Exception("wrong direction during "+name+" pos="+str(pos)+" start="+str(start_pos))
   if expected_sign<0 and pos>last+0.03: raise Exception("wrong direction during "+name+" pos="+str(pos)+" start="+str(start_pos))
   last=pos
   if at_target(d,target_path): target=True; sensor_elapsed=time.time()-t0; sensor_pos=pos; log("PHYSICAL_TARGET_REACHED leg="+name+" elapsed="+str(sensor_elapsed)+" pos="+str(pos)); break
   if time.time()-t0>3.0 and not moved:
    extra=["PRG_05_Translation.M3_RunRequest_Active","PRG_05_Translation.M3_ReqTremie_Active","PRG_05_Translation.M3_ReqMaintenance_Active","PRG_05_Translation.M3_SpeedCmd_Active","PRG_05_Translation.instTranslationM3.RampTargetPct","PRG_05_Translation.instTranslationM3.SpeedRamp.Current","PRG_05_Translation.instTranslationM3.MovementRequested","PRG_05_Translation.instTranslationM3.DirectionChangePending","PRG_05_Translation.instTranslationM3.CommandedTremie","PRG_05_Translation.instTranslationM3.CommandedMaintenance","PRG_05_Translation.instTranslationM3.EffectiveSafeStop","PRG_05_Translation.instTranslationM3.Brake.TonMagnetise.Q","PRG_05_Translation.instTranslationM3.Brake.BrakeCmd","PRG_02_Acquisition.Data.Joystick.AxisX.DirectionPositive","PRG_02_Acquisition.Data.Joystick.AxisX.DirectionNegative","PRG_02_Acquisition.Data.Joystick.DeadmanArmed","GVL_IHM.M3Translation.Cmd.InvertDirection","PRG_05_Translation.instTranslationM3.BrakeReleaseRequest","PRG_05_Translation.instTranslationM3.BrakeCommandOpenConfirmed","PRG_05_Translation.instTranslationM3.RequestedDriveControlWord","PRG_05_Translation.instTranslationM3.RequestedDriveFreqHz","PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest","PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed","PRG_06_Outputs.Data.TranslationBrakeCmd","PRG_06_Outputs.Data.M3CommandWordActive","PRG_06_Outputs.instTranslationOutputInterlockM3.Ready","PRG_06_Outputs.instTranslationOutputInterlockM3.Fault.Error","PRG_06_Outputs.instTranslationOutputInterlockM3.Fault.ErrorId","PRG_06_Outputs.instTranslationOutputInterlockM3.Reason","PRG_06_Outputs.instTranslationOutputInterlockM3.RestartInhibit","PRG_06_Outputs.instTranslationOutputInterlockM3.BrakeCmd","PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord","PRG_05_Translation.M3_SafeStop_Aggregate","PRG_05_Translation.instSafetyTranslationM3.SafeStop","PRG_05_Translation.instSafetyTranslationM3.PowerCutOff","PRG_05_Translation.instSafetyTranslationM3.Fault.Error","PRG_05_Translation.instSafetyTranslationM3.Fault.ErrorId","PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI","PRG_02_Acquisition.HwIn.Translation.M3_ThermalOK_DI"]
    extra_values={}
    for q in extra:
     try: extra_values[q]=str(oa.read_value(q))
     except Exception as ex: extra_values[q]="READ_ERROR:"+str(ex)
    log("NO_MOVE_DIAGNOSTICS="+str(extra_values))
    raise Exception("no movement observed in "+name+" after 3s")
   if n(d[PATHS[13]])>nominal_hz*1.5: raise Exception("actual frequency exceeded 1.5x target on "+name+" freq="+str(d[PATHS[13]]))
   time.sleep(0.05)
  write_bool(oa,stimulus,False); input_button=None
  if not target: raise Exception("target sensor timeout in "+name)
  stop_deadline=time.time()+10.0; stable_count=0; prev=None; stop_elapsed=None; final=None
  while time.time()<stop_deadline:
   d=snapshot(oa,stream,"STOPPING",name); pos=n(d[PATHS[2]])
   stopped=(n(d[PATHS[13]])==0.0 and b(d[PATHS[14]]))
   if stopped and prev is not None and pos==prev: stable_count+=1
   else: stable_count=0
   prev=pos; final=d
   if stable_count>=20:
    stop_elapsed=time.time()-(t0+sensor_elapsed); break
   time.sleep(0.05)
  if final is None or stop_elapsed is None: raise Exception("stop did not stabilize within 10s after "+name)
  expected_sensor=1 if target_path==PATHS[11] else 3
  sid=n(final[PATHS[5]])
  log("LEG_RESULT name="+name+" target="+str(target_path)+" start="+str(start_pos)+" sensor_pos="+str(sensor_pos)+" final_pos="+str(final[PATHS[2]])+" overshoot="+str(final[PATHS[4]])+" overshoot_sensor_id="+str(sid)+" expected_sensor_id="+str(expected_sensor)+" sensor_elapsed_s="+str(sensor_elapsed)+" stop_elapsed_s="+str(stop_elapsed)+" max_actual_freq_hz="+str(maxfreq)+" stopped="+str(stopped)+" stable_samples="+str(stable_count))
  if target_path!=PATHS[12] and sid!=expected_sensor: raise Exception("overshoot sensor id mismatch in "+name+": "+str(sid))
  if target_path==PATHS[12] and sid!=expected_sensor: log("P1_return_sensor_id_unverified_cumulative_DI="+str(sid)+" expected="+str(expected_sensor))
  return {"skipped":False,"start":start_pos,"finish":n(final[PATHS[2]]),"overshoot":n(final[PATHS[4]]),"sensor_id":sid,"sensor_elapsed":sensor_elapsed,"stop_elapsed":stop_elapsed,"max_freq":maxfreq}
  
  
 results=[]
 results.append(leg("10Hz_P1_to_Tremie",BTN_RIGHT,PATHS[11],-1,10.0,45.0))
 results.append(leg("10Hz_Tremie_to_P1",BTN_LEFT,PATHS[12],1,10.0,45.0))
 write(oa,SET_FREQ,"20.0")
 deadline=time.time()+2.0
 while time.time()<deadline:
  d=read(oa)
  if abs(n(d[PATHS[30]])-20.0)<0.001: break
  time.sleep(0.1)
 if abs(n(d[PATHS[30]])-20.0)>0.001: raise Exception("20Hz setpoint not accepted")
 results.append(leg("20Hz_P1_to_Tremie",BTN_RIGHT,PATHS[11],-1,20.0,35.0))
 results.append(leg("20Hz_Tremie_to_P1",BTN_LEFT,PATHS[12],1,20.0,35.0))
 log("ALL_LEGS_COMPLETED="+str(results))
except Exception as e:
 log("EXCEPTION="+str(e))
finally:
 if oa is not None:
  try:
   if oa.is_logged_in:
    if input_button is not None:
     try: write_bool(oa,input_button,False); log("cleanup_active_joystick_stimulus=False")
     except Exception as e: log("cleanup_stimulus_error="+str(e))
    if reset_command_written:
     try: write_bool(oa,RESET_BUTTON,False); log("cleanup_reset_command_false=True")
     except Exception as e: log("cleanup_reset_command_error="+str(e))
    if arm_command_written:
     try: write_bool(oa,ARM_BUTTON,False); log("cleanup_arm_command_false=True")
     except Exception as e: log("cleanup_arm_command_error="+str(e))
    for stim in (BTN_RIGHT,BTN_LEFT):
     try: write_bool(oa,stim,False)
     except Exception as e: log("cleanup_stimulus_error="+str(e))
    if freq_changed and original_freq is not None:
     try: write(oa,SET_FREQ,str(original_freq)); log("cleanup_set_freq_restored="+str(original_freq))
     except Exception as e: log("cleanup_set_freq_error="+str(e))
    if mode_changed and original_mode is not None:
     try: write(oa,SEL_MODE,{"DISABLE":"0","MAINT_N1":"1","MAINT_N2":"2","SEMI_AUTO":"3"}.get(str(original_mode),"0")); log("cleanup_mode_restored="+str(original_mode))
     except Exception as e: log("cleanup_mode_error="+str(e))
    try: write_bool(oa,"GVL_IHM.M3Translation.Bypass.MinHeight",False); log("cleanup_MinHeight_bypass_false=True")
    except Exception as e: log("cleanup_MinHeight_bypass_error="+str(e))
    if master_written:
     try: write_bool(oa,MASTER,False); log("cleanup_sim_master_false=True")
     except Exception as e: log("cleanup_master_error="+str(e))
    try:
     for m in ("unforce_all_values","UnforceAll","unforce_prepared_values","UnforcePreparedValues","unforce_all"):
      if hasattr(oa,m): getattr(oa,m)(); log("cleanup_unforce=True"); break
    except Exception as e: log("cleanup_unforce_error="+str(e))
    deadline=time.time()+10.0
    while time.time()<deadline:
     try:
      d=read(oa)
      if not b(d[MASTER]) and not b(d[SIM_M3]): break
     except: pass
     time.sleep(0.1)
    if oa.application_state==ApplicationState.run: oa.stop(); log("application_stopped=True")
    log("final_state="+str(oa.application_state))
    oa.logout(); log("logout=True")
  except Exception as e: log("cleanup_error="+str(e))
  try: oa.Dispose()
  except: pass
 if p is not None:
  try: p.close()
  except: pass
 if stream is not None:
  try: stream.close()
  except: pass
 log("SCRIPT_FINISHED=True")
