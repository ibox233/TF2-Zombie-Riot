#pragma semicolon 1
#pragma newdecls required

StringMap WeaponAttributes[MAXENTITIES + 1];

bool Attribute_ServerSide(int attribute)
{
	switch(attribute)
	{
		case 733, 309, 777, 701, 805, 180, 830, 785, 405, 527, 319: //gibs on hit
		{
			return true;
		}
		case 57, 190, 191, 218, 366, 651,33,731,719,544,410,786,3002,3000,149,208,638,17,71,868,122,225, 224,205,206, 412, 4001, 4002:
		{
			return true;
		}
	}
	return false;
}
void Attributes_EntityDestroyed(int entity)
{
	delete WeaponAttributes[entity];
}

stock bool Attributes_RemoveAll(int entity)
{
	delete WeaponAttributes[entity];
	return TF2Attrib_RemoveAll(entity);
}

bool Attributes_Has(int entity, int attrib)
{
	if(!WeaponAttributes[entity])
		return false;
	
	char buffer[6];
	IntToString(attrib, buffer, sizeof(buffer));
	return WeaponAttributes[entity].ContainsKey(buffer);
}

float Attributes_Get(int entity, int attrib, float defaul = 1.0)
{
	if(WeaponAttributes[entity])
	{
		float value = defaul;

		char buffer[6];
		IntToString(attrib, buffer, sizeof(buffer));
		if(WeaponAttributes[entity].GetValue(buffer, value))
			return value;
	}
	
	return defaul;
}

bool Attributes_Set(int entity, int attrib, float value)
{
	if(!WeaponAttributes[entity])
		WeaponAttributes[entity] = new StringMap();
	
	char buffer[6];
	IntToString(attrib, buffer, sizeof(buffer));
	WeaponAttributes[entity].SetValue(buffer, value);

	if(Attribute_ServerSide(attrib))
		return false;
	
	TF2Attrib_SetByDefIndex(entity, attrib, value);
	return true;
}

stock void Attributes_SetAdd(int entity, int attrib, float amount)
{
	char buffer[6];
	IntToString(attrib, buffer, sizeof(buffer));

	float value = 0.0;

	if(WeaponAttributes[entity])
	{
		WeaponAttributes[entity].GetValue(buffer, value);
	}
	else
	{
		WeaponAttributes[entity] = new StringMap();
	}

	value += amount;

	WeaponAttributes[entity].SetValue(buffer, value);
	if(!Attribute_ServerSide(attrib))
		Attributes_Set(entity, attrib, value);
}

stock void Attributes_SetMulti(int entity, int attrib, float amount)
{
	char buffer[6];
	IntToString(attrib, buffer, sizeof(buffer));

	float value = 1.0;

	if(WeaponAttributes[entity])
	{
		WeaponAttributes[entity].GetValue(buffer, value);
	}
	else
	{
		WeaponAttributes[entity] = new StringMap();
	}

	value *= amount;

	WeaponAttributes[entity].SetValue(buffer, value);
	if(!Attribute_ServerSide(attrib))
		Attributes_Set(entity, attrib, value);
}

stock bool Attributes_GetString(int entity, int attrib, char[] value, int length, int &size = 0)
{
	if(!WeaponAttributes[entity])
		return false;

	char buffer[6];
	IntToString(attrib, buffer, sizeof(buffer));
	return WeaponAttributes[entity].GetString(buffer, value, length, size);
}

stock void Attributes_SetString(int entity, int attrib, const char[] value)
{
	if(!WeaponAttributes[entity])
		WeaponAttributes[entity] = new StringMap();
	
	char buffer[6];
	IntToString(attrib, buffer, sizeof(buffer));
	WeaponAttributes[entity].SetString(buffer, value);
}

#if defined ZR
bool Attributes_Fire(int weapon)
{
	int clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	if(clip > 0)
	{
		float gameTime = GetGameTime();
		if(gameTime < GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack"))
		{
			float value = Attributes_Get(weapon, 298, 0.0);	// mod ammo per shot
			if(value && clip < RoundFloat(value))
			{
				SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", gameTime + 0.2);
				return true;
			}
		}
	}
	return false;
}
#endif

#if defined RPG
int Attributes_Airdashes(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	return RoundFloat(Attributes_Get(weapon, 250, 0.0) + Attributes_GetOnPlayer(client, 393, false));	// air dash count, sniper rage DISPLAY ONLY
}
#endif

void Attributes_OnHit(int client, int victim, int weapon, float &damage, int& damagetype, bool &guraneedGib)
{
	{
		if(weapon < 1)
		{
			return;
		}

		if(!(damagetype & DMG_SLASH)) //Exclude itself so it doesnt do inf repeats! no weapon uses slash so we will use slash for any debuffs onto zombies that stacks
		{
			if(!(i_HexCustomDamageTypes[victim] & ZR_DAMAGE_DO_NOT_APPLY_BURN_OR_BLEED))
			{
				float value = Attributes_Get(weapon, 16, 0.0) +
					Attributes_Get(weapon, 98, 0.0) +
					Attributes_Get(weapon, 110, 0.0) +
					Attributes_Get(weapon, 111, 0.0);	// add_onhit_addhealth
					
				if(value)
				{
					HealEntityGlobal(client, client, value, 1.0, 0.0, HEAL_SELFHEAL);
				}
				
				value = Attributes_Get(weapon, 149, 0.0);	// bleeding duration
				if(value)
					StartBleedingTimer(victim, client, Attributes_Get(weapon, 2, 1.0) * 4.0, RoundFloat(value * 2.0), weapon, damagetype);
				
				value = Attributes_Get(weapon, 208, 0.0);	// Set DamageType Ignite

				int itemdefindex = -1;
				if(IsValidEntity(weapon) && weapon >= MaxClients)
				{
					itemdefindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
				}
				if(value || (itemdefindex ==  594 || itemdefindex == 208)) //Either this attribute, or burn damamage!
				{

					if(value == 1.0)
						value = 7.5;

					if(value < 1.0)
						value = 2.0;
						
					NPC_Ignite(victim, client, value, weapon);
				}	
				
				if(Attributes_Get(weapon, 638, 0.0))	// Extinquisher
				{
					if(IgniteFor[victim] > 0)
					{
						damage *= 1.5;
						DisplayCritAboveNpc(victim, client, true);
					}
					//dont actually extinquish, just give them more damage.
				}
				
				value = Attributes_Get(weapon, 17, 0.0);
				if(value)
				{
					if(!TF2_IsPlayerInCondition(client, TFCond_Ubercharged)) //No infinite uber chain.
					{
						// add uber charge on hit
						
						ArrayList list = new ArrayList();
							
						int entity, i;
						while(TF2_GetItem(client, entity, i))
						{
							if(b_IsAMedigun[entity])	//if(HasEntProp(entity, Prop_Send, "m_flChargeLevel"))
								list.Push(entity);
						}

						int length = list.Length;
						if(length)
						{
							value /= float(length);
							float extra;
							for(i = length - 1; i >= 0; i--)
							{
								entity = list.Get(i);
								float uber = GetEntPropFloat(entity, Prop_Send, "m_flChargeLevel");
								if(Attributes_Get(entity, 2046, 0.0) == 4.0)
								{
									uber -= value + extra;
								}
								else
								{
									uber += value + extra;
								}
									
								if(uber > 1.0)
								{
									extra = uber - 1.0;
									uber = 1.0;
								}
								else if(uber < 0.0)
								{
									extra = -uber;
									uber = 0.0;
								}
								else
								{
									extra = 0.0;
								}
									
								SetEntPropFloat(entity, Prop_Send, "m_flChargeLevel", uber);
							}
						}
						delete list;
					}
				}
			}
		}
		float value = Attributes_Get(weapon, 877, 0.0);	// speed_boost_on_hit_enemy
		if(value)
			TF2_AddCondition(client, TFCond_SpeedBuffAlly, value);

		value = Attributes_Get(weapon, 309, 0.0);	// Gib on crit, in this case, guranted gibs
		if(value)
			guraneedGib = true;

			
		value = Attributes_Get(weapon, 225, 0.0);	// if Above Half Health
		if(value)
		{
			float flMaxHealth = float(SDKCall_GetMaxHealth(client));
			float flHealth = float(GetEntProp(client, Prop_Data, "m_iHealth"));
			if((flHealth / flMaxHealth) >= 0.5)
			{
				damage *= value;
			} 
		}

		value = Attributes_Get(weapon, 224, 0.0);	// if Below Half Health
		if(value)
		{
			float flMaxHealth = float(SDKCall_GetMaxHealth(client));
			float flHealth = float(GetEntProp(client, Prop_Data, "m_iHealth"));
			if((flHealth / flMaxHealth) <= 0.5)
			{
				damage *= value;
			} 
		}
		
		value = Attributes_Get(weapon, 366, 0.0);	// mod stun waist high airborne
		if(value)
		{
			if(b_thisNpcIsABoss[victim] || b_thisNpcIsARaid[victim])
			{
				value /= 2.0;
			}

			if(b_thisNpcIsARaid[victim])
			{
				if(value > 1.5)
					value = 1.5;
			}
			
			FreezeNpcInTime(victim, value);
		}

		value = Attributes_Get(weapon, 218, 0.0);	// mark for death
		if(value)
		{
			NpcStats_SilenceEnemy(victim, value);
		}

		/*
		if(Attributes_GetOnPlayer(client, weapon, 2067))	// attack_minicrits_and_consumes_burning
		{
			int ticks = NPC_Extinguish(victim);
			if(ticks)
			{
				EmitGameSoundToClient(client, "TFPlayer.FlameOut", victim);
				damage += ticks*4.0;
				TF2_AddCondition(client, TFCond_NoHealingDamageBuff, 0.1);
			}
		}
		*/
	}
}

void Attributes_OnKill(int client, int weapon)
{

	SetEntProp(client, Prop_Send, "m_iKills", GetEntProp(client, Prop_Send, "m_iKills") + 1);

	float value;

	value = Attributes_GetOnPlayer(client, 387, false);	// rage on kill
	if(value)
	{
		float rage = GetEntPropFloat(client, Prop_Send, "m_flRageMeter") + value;
		if(rage > 100.0)
			rage = 100.0;
		
		SetEntPropFloat(client, Prop_Send, "m_flRageMeter", rage);
	}

	if(IsValidEntity(weapon) && weapon > MaxClients)
	{
		value = Attributes_Get(weapon, 180, 0.0);	// heal on kill

		if(value)
		{
			HealEntityGlobal(client, client, value, 1.0, 1.0, HEAL_SELFHEAL);
		}
		
		value = Attributes_Get(weapon, 613, 0.0);	// minicritboost on kill
		if(value)
			TF2_AddCondition(client, TFCond_MiniCritOnKill, value);

		if(Attributes_Get(weapon, 644,0.0) || Attributes_Get(weapon, 807,0.0))	// clipsize increase on kill, add_head_on_kill
			SetEntProp(client, Prop_Send, "m_iDecapitations", GetEntProp(client, Prop_Send, "m_iDecapitations")+1);
			
	}


}

float Attributes_GetOnPlayer(int client, int index, bool multi = true, bool noWeapons = false)
{
	float defaul = multi ? 1.0 : 0.0;
	float result = Attributes_Get(client, index, defaul);
	
	int entity = MaxClients + 1;
	while(TF2_GetWearable(client, entity))
	{
		float value = Attributes_Get(entity, index, defaul);
		if(value != defaul)
		{
			if(multi)
			{
				result *= value;
			}
			else
			{
				result += value;
			}
		}
	}
	
	if(!noWeapons)
	{
		int active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

		int i;
		while(TF2_GetItem(client, entity, i))
		{
			if(index != 128 && active != entity)
			{
				if(Attributes_Get(entity, 128, 0.0))
					continue;
			}
			
			float value = Attributes_Get(entity, index, defaul);
			if(value != defaul)
			{
				if(multi)
				{
					result *= value;
				}
				else
				{
					result += value;
				}
			}
		}
	}
	
	return result;
}

float Attributes_GetOnWeapon(int client, int entity, int index, bool multi = true, float defaultstat = -1.0)
{
	float defaul = multi ? 1.0 : 0.0;
	if(defaultstat != -1.0)
	{	
		defaul = defaultstat;
	}
	float result = Attributes_Get(client, index, defaul);
	
	int wearable = MaxClients + 1;
	while(TF2_GetWearable(client, wearable))
	{
		float value = Attributes_Get(wearable, index, defaul);
		if(value != defaul)
		{
			if(multi)
			{
				result *= value;
			}
			else
			{
				result += value;
			}
		}
	}
	
	if(entity > MaxClients)
	{
		float value = Attributes_Get(entity, index, defaul);
		if(value != defaul)
		{
			if(multi)
			{
				result *= value;
			}
			else
			{
				result += value;
			}
		}
	}
	
	return result;
}

stock float Attributes_FindOnWeapon(int client, int entity, int index, bool multi=false, float defaul=0.0)
{
	return Attributes_Get(entity, index, defaul);
}

stock float Attributes_FindOnPlayerZR(int client, int index, bool multi=false, float defaul=0.0, bool IgnoreWeaponsEquipped = false, bool DoNotIngoreEquippedWeapon = false)
{
	if(IgnoreWeaponsEquipped && DoNotIngoreEquippedWeapon)
		return Attributes_GetOnWeapon(client, GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"), index, multi);
	
	return Attributes_GetOnPlayer(client, index, multi, IgnoreWeaponsEquipped);
}