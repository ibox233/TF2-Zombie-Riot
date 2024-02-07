#pragma semicolon 1
#pragma newdecls required

static char g_HurtSounds[][] =
{
	"cof/purnell/hurt1.mp3",
	"cof/purnell/hurt2.mp3",
	"cof/purnell/hurt3.mp3",
	"cof/purnell/hurt4.mp3"
};

static char g_KillSounds[][] =
{
	"cof/purnell/kill1.mp3",
	"cof/purnell/kill2.mp3",
	"cof/purnell/kill3.mp3",
	"cof/purnell/kill4.mp3"
};
static float i_ClosestAllyCDTarget[MAXENTITIES];
/*
void SpecialDoctor_MapStart()
{
	for (int i = 0; i < (sizeof(g_HurtSounds));	   i++) { PrecacheSoundCustom(g_HurtSounds[i]);	   }
	for (int i = 0; i < (sizeof(g_KillSounds));	   i++) { PrecacheSoundCustom(g_KillSounds[i]);	   }
	PrecacheSoundCustom("cof/purnell/death.mp3");
	PrecacheSoundCustom("cof/purnell/intro.mp3");
	PrecacheSoundCustom("cof/purnell/converted.mp3");
	PrecacheSoundCustom("cof/purnell/reload.mp3");
	PrecacheSoundCustom("cof/purnell/shoot.mp3");
	PrecacheSoundCustom("cof/purnell/shove.mp3");
	PrecacheSoundCustom("cof/purnell/meleehit.mp3");

	PrecacheModel("models/zombie_riot/cof/doctor_purnell.mdl");
}
*/


static char[] GetPanzerHealth()
{
	int health = 110;
	
	health *= CountPlayersOnRed(); //yep its high! will need tos cale with waves expoentially.
	
	float temp_float_hp = float(health);
	
	if(ZR_GetWaveCount()+1 < 30)
	{
		health = RoundToCeil(Pow(((temp_float_hp + float(ZR_GetWaveCount()+1)) * float(ZR_GetWaveCount()+1)),1.20));
	}
	else if(ZR_GetWaveCount()+1 < 45)
	{
		health = RoundToCeil(Pow(((temp_float_hp + float(ZR_GetWaveCount()+1)) * float(ZR_GetWaveCount()+1)),1.25));
	}
	else
	{
		health = RoundToCeil(Pow(((temp_float_hp + float(ZR_GetWaveCount()+1)) * float(ZR_GetWaveCount()+1)),1.35)); //Yes its way higher but i reduced overall hp of him
	}
	
	health /= 2;
	
	char buffer[16];
	IntToString(health, buffer, sizeof(buffer));
	return buffer;
}
methodmap SpecialDoctor < CClotBody
{
	public void PlayHurtSound()
	{
		if(this.m_flNextHurtSound > GetGameTime(this.index))
			return;
		
		this.m_flNextHurtSound = GetGameTime(this.index) + 1.0;
		EmitCustomToAll(g_HurtSounds[GetRandomInt(0, sizeof(g_HurtSounds) - 1)], this.index, SNDCHAN_VOICE, BOSS_ZOMBIE_SOUNDLEVEL, _, 2.0);
	}
	public void PlayDeathSound()
	{
		EmitCustomToAll("cof/purnell/death.mp3", _, _, _, _, 2.0);
	}
	public void PlayIntroSound()
	{
		EmitCustomToAll("cof/purnell/intro.mp3", _, _, _, _, 3.0);
	}
	public void PlayFriendlySound()
	{
		EmitCustomToAll("cof/purnell/converted.mp3", this.index, SNDCHAN_AUTO, BOSS_ZOMBIE_SOUNDLEVEL, _, 2.0);
	}
	public void PlayReloadSound()
	{
		EmitCustomToAll("cof/purnell/reload.mp3", this.index, SNDCHAN_AUTO, BOSS_ZOMBIE_SOUNDLEVEL, _, 1.75);
	}
	public void PlayShootSound()
	{
		EmitCustomToAll("cof/purnell/shoot.mp3", this.index, SNDCHAN_AUTO, BOSS_ZOMBIE_SOUNDLEVEL, _, 2.7);
	}
	public void PlayMeleeSound()
	{
		this.m_flNextHurtSound = GetGameTime(this.index) + 1.0;
		EmitCustomToAll("cof/purnell/shove.mp3", this.index, SNDCHAN_AUTO, BOSS_ZOMBIE_SOUNDLEVEL, _, 3.0);
	}
	public void PlayHitSound()
	{
		EmitCustomToAll("cof/purnell/meleehit.mp3", this.index, SNDCHAN_AUTO, BOSS_ZOMBIE_SOUNDLEVEL, _, 3.0);
	}
	public void PlayKillSound()
	{
		this.m_flNextHurtSound = GetGameTime(this.index) + 2.0;
		EmitCustomToAll(g_KillSounds[GetRandomInt(0, sizeof(g_KillSounds) - 1)], this.index, SNDCHAN_AUTO, BOSS_ZOMBIE_SOUNDLEVEL, _, 3.0);
	}

	public SpecialDoctor(int client, float vecPos[3], float vecAng[3], bool ally, const char[] data)
	{
		SpecialDoctor npc = view_as<SpecialDoctor>(CClotBody(vecPos, vecAng, "models/zombie_riot/cof/doctor_purnell.mdl", "1.15", GetPanzerHealth(), ally));
		i_NpcInternalId[npc.index] = THEDOCTOR_MINIBOSS;
		i_NpcWeight[npc.index] = 3;
		
		npc.m_iState = -1;
		npc.SetActivity("ACT_SPAWN");
		
		if(ally)
		{
			npc.PlayFriendlySound();
		}
		else
		{
			npc.PlayIntroSound();
		}
		
		npc.m_iBleedType = BLEEDTYPE_NORMAL;
		npc.m_iStepNoiseType = STEPSOUND_GIANT;
		npc.m_iNpcStepVariation = STEPTYPE_NORMAL;
		
		SDKHook(npc.index, SDKHook_OnTakeDamagePost, SpecialDoctor_ClotDamagedPost);
		
		npc.m_iInjuredLevel = 0;
		npc.m_bThisNpcIsABoss = true;
		npc.m_iTarget = -1;
		npc.m_flGetClosestTargetTime = 0.0;
		npc.m_bDissapearOnDeath = false;
		i_ClosestAllyCDTarget[npc.index] = 0.0;
		
		npc.m_flNextMeleeAttack = 0.0;
		npc.m_flAttackHappens = 0.0;
		
		npc.m_flNextRangedAttack = 0.0;
		npc.m_iAttacksTillReload = 5;
		npc.m_flReloadDelay = GetGameTime(npc.index) + 0.8;

		float wave = float(ZR_GetWaveCount()+1);
		wave *= 0.1;
		npc.m_flWaveScale = wave;
		
		npc.m_flNextRangedSpecialAttack = 0.0;


		func_NPCDeath[npc.index] = view_as<Function>(SpecialDoctor_NPCDeath);
		func_NPCThink[npc.index] = view_as<Function>(SpecialDoctor_ClotThink);

		Citizen_MiniBossSpawn();
		return npc;
	}
	
	public void SetActivity(const char[] animation)
	{
		int activity = this.LookupActivity(animation);
		if(activity > 0 && activity != this.m_iState)
		{
			this.m_iState = activity;
			//this.m_bisWalking = false;
			this.StartActivity(activity);
		}
	}
	property int m_iInjuredLevel
	{
		public get()		{ return this.m_iMedkitAnnoyance; }
		public set(int value) 	{ this.m_iMedkitAnnoyance = value; }
	}
}

public void SpecialDoctor_ClotThink(int iNPC)
{
	SpecialDoctor npc = view_as<SpecialDoctor>(iNPC);
	
	SetVariantInt(npc.m_iInjuredLevel);
	AcceptEntityInput(npc.index, "SetBodyGroup");
	
	float gameTime = GetGameTime(npc.index);
	if(npc.m_flNextThinkTime > gameTime)
		return;
	
	npc.m_flNextThinkTime = gameTime + 0.04;
	npc.Update();
	
	if(npc.m_flNextRangedSpecialAttack < gameTime)
	{
		npc.m_flNextRangedSpecialAttack = gameTime + 0.25;
		
		int target = GetClosestAlly(npc.index, (250.0 * 250.0), _,DoctorBuffAlly);
		if(target)
		{
			if(!b_PernellBuff[target])
			{
				b_PernellBuff[target] = true;
				npc.AddGesture("ACT_SIGNAL");
			}
		}
	}
	
	if(npc.m_iTarget > 0 && !IsValidEnemy(npc.index, npc.m_iTarget))
	{
		if(npc.m_iTarget <= MaxClients)
			npc.PlayKillSound();
		
		npc.m_iTarget = 0;
		npc.m_flGetClosestTargetTime = 0.0;
	}

	if(!IsValidAlly(npc.index, npc.m_iTargetAlly))
	{
		if(i_ClosestAllyCDTarget[npc.index] < GetGameTime(npc.index))
		{
			npc.m_iTargetAlly = GetClosestAlly(npc.index, _, _,DoctorBuffAlly);
			i_ClosestAllyCDTarget[npc.index] = GetGameTime(npc.index) + 1.0;
		}
	}
	else
	{
		i_ClosestAllyCDTarget[npc.index] = GetGameTime(npc.index) + 0.0;
	}

	if(npc.m_flGetClosestTargetTime < gameTime)
	{
		npc.m_flGetClosestTargetTime = gameTime + 0.5;
		npc.m_iTarget = GetClosestTarget(npc.index, true);
	}
	if(IsValidAlly(npc.index, npc.m_iTargetAlly) && IsValidEnemy(npc.index, npc.m_iTarget))
	{
		float vecTargetally[3]; vecTargetally = WorldSpaceCenterOld(npc.m_iTargetAlly);
		float vecTarget[3]; vecTarget = WorldSpaceCenterOld(npc.m_iTarget);
		float vecPos[3]; vecPos = WorldSpaceCenterOld(npc.index);
		
		float distanceToAlly = GetVectorDistance(vecTargetally, vecPos, true);
		float distanceToEnemy = GetVectorDistance(vecTarget, vecTargetally, true);
		if(distanceToAlly > (140.0 * 140.0) && npc.m_iTargetWalkTo < (50.0 * 50.0)) //get close to ally but not too close
		{
			npc.m_iTargetWalkTo = npc.m_iTargetAlly;
		}
		else
		{
			if(distanceToEnemy < (200.0 * 200.0)) //enemy is too close to friend, follow enemy
			{
				npc.m_iTargetWalkTo = npc.m_iTargetAlly;
			}
		}
	}
	else
	{
		npc.m_iTargetWalkTo = npc.m_iTarget;
	}
	
	int behavior = -1;
	
	if(npc.m_flAttackHappens)
	{
		if(npc.m_flAttackHappens < gameTime)
		{
			npc.m_flAttackHappens = 0.0;
			npc.m_iAttacksTillReload++;
			
			if(IsValidEnemy(npc.index, npc.m_iTarget))
			{
				Handle swingTrace;
				npc.FaceTowards(WorldSpaceCenterOld(npc.m_iTarget), 15000.0);
				if(npc.DoSwingTrace(swingTrace, npc.m_iTarget))
				{
					int target = TR_GetEntityIndex(swingTrace);	
					
					float vecHit[3];
					TR_GetEndPosition(vecHit, swingTrace);
					
					if(target > 0) 
					{
						float damage = 50.0;
											
											
						if(!ShouldNpcDealBonusDamage(target))
							SDKHooks_TakeDamage(target, npc.index, npc.index, damage * npc.m_flWaveScale, DMG_CLUB, -1, _, vecHit);
						else
							SDKHooks_TakeDamage(target, npc.index, npc.index, damage * 3.0 * npc.m_flWaveScale, DMG_CLUB, -1, _, vecHit);

						Custom_Knockback(npc.index, target, 500.0);
						npc.m_iAttacksTillReload++;
						npc.PlayHitSound();
					}
				}
				delete swingTrace;
			}
		}
		
		behavior = 0;
	}
	
	if(behavior == -1)
	{
		if(npc.m_iTarget > 0 && npc.m_iTargetWalkTo > 0)	// We have a target
		{
			float vecPos[3]; vecPos = WorldSpaceCenterOld(npc.index);
			float vecTarget[3]; vecTarget = WorldSpaceCenterOld(npc.m_iTarget);
			
			float distance = GetVectorDistance(vecTarget, vecPos, true);
			if(distance < 10000.0 && npc.m_flNextMeleeAttack < gameTime)	// Close at any time: Melee
			{
				npc.FaceTowards(vecTarget, 15000.0);
				
				npc.AddGesture("ACT_SHOVE");
				npc.PlayMeleeSound();
				
				npc.m_flAttackHappens = gameTime + 0.3;
				npc.m_flReloadDelay = gameTime + 0.6;
				npc.m_flNextMeleeAttack = gameTime + 1.0;
				
				behavior = 0;
			}
			else if(npc.m_flReloadDelay > gameTime)	// Reloading
			{
				behavior = 0;
			}
			else if(distance < 80000.0)	// In shooting range
			{
				if(npc.m_flNextRangedAttack < gameTime)	// Not in attack cooldown
				{
					if(npc.m_iAttacksTillReload > 0)	// Has ammo
					{
						int Enemy_I_See;
				
						Enemy_I_See = Can_I_See_Enemy(npc.index, npc.m_iTarget);
						//Target close enough to hit
						if(IsValidEnemy(npc.index, npc.m_iTarget) && npc.m_iTarget == Enemy_I_See)
						{
							behavior = 0;
							npc.SetActivity("ACT_IDLE");
							
							npc.FaceTowards(vecTarget, 15000.0);
							
							npc.AddGesture("ACT_SHOOT");
							
							npc.m_flNextRangedAttack = gameTime + 1.0;
							npc.m_iAttacksTillReload--;
							
							vecTarget = PredictSubjectPositionForProjectilesOld(npc, npc.m_iTarget, 700.0);
							float damage = 50.0;

							npc.FireRocket(vecTarget, damage * 0.9 * npc.m_flWaveScale, 700.0, "models/weapons/w_bullet.mdl", 2.0);
							
							npc.PlayShootSound();
						}
						else	// Something in the way, move closer
						{
							behavior = 1;
						}
					}
					else	// No ammo, retreat
					{
						behavior = 3;
					}
				}
				else	// In attack cooldown
				{
					behavior = 0;
					npc.SetActivity("ACT_IDLE");
				}
			}
			else if(npc.m_iAttacksTillReload < 0)	// Take the time to reload
			{
				//Only if low ammo, otherwise it can be abused.
				behavior = 4;
			}
			else	// Sprint Time
			{
				behavior = 2;
			}
		}
		else if(npc.m_flReloadDelay > gameTime)	// Reloading...
		{
			behavior = 0;
		}
		else if(npc.m_iAttacksTillReload < 5)	// Nobody here..?
		{
			behavior = 4;
		}
		else	// What do I do...
		{
			behavior = 0;
			npc.SetActivity("ACT_GMOD_TAUNT_DANCE");
		}
	}
	
	// Reload anyways if we can't run
	if(npc.m_flRangedSpecialDelay && behavior == 3 && npc.m_flRangedSpecialDelay > gameTime)
		behavior = 4;
	
	switch(behavior)
	{
		case 0:	// Stand
		{
			// Activity handled above
			npc.m_flSpeed = 0.0;
			
			if(npc.m_bPathing)
			{
				NPC_StopPathing(npc.index);
				npc.m_bPathing = false;
			}
		}
		case 1:	// Move After the Player
		{
			npc.SetActivity("ACT_RUN");
			npc.m_flSpeed = 200.0;
			npc.m_flRangedSpecialDelay = 0.0;
			
			NPC_SetGoalEntity(npc.index, npc.m_iTargetWalkTo);
			if(!npc.m_bPathing)
				npc.StartPathing();
		}
		case 2:	// Sprint After the Player
		{
			npc.SetActivity("ACT_RUN");
			npc.m_flSpeed = 250.0;
			npc.m_flRangedSpecialDelay = 0.0;
			
			NPC_SetGoalEntity(npc.index, npc.m_iTargetWalkTo);
			if(!npc.m_bPathing)
				npc.StartPathing();
		}
		case 3:	// Retreat
		{
			npc.SetActivity("ACT_RUNHIDE");
			npc.m_flSpeed = 500.0;
			
			if(!npc.m_flRangedSpecialDelay)	// Reload anyways timer
				npc.m_flRangedSpecialDelay = gameTime + 4.0;
			
			float vBackoffPos[3]; vBackoffPos = BackoffFromOwnPositionAndAwayFromEnemyOld(npc, npc.m_iTargetWalkTo);
			NPC_SetGoalVector(npc.index, vBackoffPos);
			
			if(!npc.m_bPathing)
				npc.StartPathing();
		}
		case 4:	// Reload
		{
			npc.AddGesture("ACT_RELOAD");
			npc.m_flSpeed = 0.0;
			npc.m_flRangedSpecialDelay = 0.0;
			npc.m_flReloadDelay = gameTime + 4.25;
			npc.m_iAttacksTillReload = 5;
			
			if(npc.m_bPathing)
			{
				NPC_StopPathing(npc.index);
				npc.m_bPathing = false;
			}
			
			npc.PlayReloadSound();
		}
	}
}

public void SpecialDoctor_ClotDamagedPost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if(damage > 0.0)
	{
		SpecialDoctor npc = view_as<SpecialDoctor>(victim);
		npc.m_iInjuredLevel = 4 - (GetEntProp(victim, Prop_Data, "m_iHealth") * 5 / GetEntProp(victim, Prop_Data, "m_iMaxHealth"));
		
		npc.PlayHurtSound();
	}
}

public void SpecialDoctor_NPCDeath(int entity)
{
	SpecialDoctor npc = view_as<SpecialDoctor>(entity);
	
	SDKUnhook(npc.index, SDKHook_OnTakeDamagePost, SpecialDoctor_ClotDamagedPost);
	
	npc.PlayDeathSound();

	Citizen_MiniBossDeath(entity);
}


public bool DoctorBuffAlly(int provider, int entity)
{
	if(b_PernellBuff[entity])
		return false;

	return true;
}