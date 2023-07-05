#pragma semicolon 1
#pragma newdecls required

static int VillagerSpecialCommand[MAXENTITIES];
static int VillagerTowerLink[MAXENTITIES];
static float VillagerRemindbuild[MAXENTITIES];
static float VillagerBuildCooldown[MAXENTITIES];
static float VillagerDesiredBuildLocation[MAXENTITIES][3];
static float VillagerRepairFocusLoc[MAXENTITIES][3];

enum
{
	Villager_Command_Default = -1,
	Villager_Command_RepairFocus = 0,
	Villager_Command_GatherResource = 1,
	Villager_Command_StandNearTower = 2,
}

methodmap BarrackVillager < BarrackBody
{
	property float f_VillagerBuildCooldown
	{
		public get()
		{
			return VillagerBuildCooldown[view_as<int>(this)];
		}
		public set(float value)
		{
			VillagerBuildCooldown[view_as<int>(this)] = value;
		}
	}
	property float f_VillagerRemind
	{
		public get()
		{
			return VillagerRemindbuild[view_as<int>(this)];
		}
		public set(float value)
		{
			VillagerRemindbuild[view_as<int>(this)] = value;
		}
	}
	property int i_VillagerSpecialCommand
	{
		public get()
		{
			return VillagerSpecialCommand[view_as<int>(this)];
		}
		public set(int value)
		{
			VillagerSpecialCommand[view_as<int>(this)] = value;
		}
	}
	property int m_iTowerLinked
	{
		public get()		 
		{ 
			return EntRefToEntIndex(VillagerTowerLink[this.index]); 
		}
		public set(int iInt) 
		{
			if(iInt == -1)
			{
				VillagerTowerLink[this.index] = INVALID_ENT_REFERENCE;
			}
			else
			{
				VillagerTowerLink[this.index] = EntIndexToEntRef(iInt);
			}
		}
	}
	public BarrackVillager(int client, float vecPos[3], float vecAng[3], bool ally)
	{
		BarrackVillager npc = view_as<BarrackVillager>(BarrackBody(client, vecPos, vecAng, "1000"));
		
		i_NpcInternalId[npc.index] = BARRACKS_VILLAGER;
		i_NpcWeight[npc.index] = 1;
		
		SDKHook(npc.index, SDKHook_Think, BarrackVillager_ClotThink);

		npc.m_flSpeed = 150.0;
		npc.i_VillagerSpecialCommand = Villager_Command_Default;
		npc.m_iTowerLinked = -1;
		npc.b_NpcSpecialCommand = true;
		npc.f_VillagerRemind = 0.0;
		npc.f_VillagerBuildCooldown = 0.0;
		VillagerDesiredBuildLocation[npc.index][0] = 0.0;
		VillagerDesiredBuildLocation[npc.index][1] = 0.0;
		VillagerDesiredBuildLocation[npc.index][2] = 0.0;
		VillagerRepairFocusLoc[npc.index][0] = 0.0;
		VillagerRepairFocusLoc[npc.index][1] = 0.0;
		VillagerRepairFocusLoc[npc.index][2] = 0.0;
		
		npc.m_iWearable1 = npc.EquipItem("weapon_bone", "models/workshop/weapons/c_models/c_sledgehammer/c_sledgehammer.mdl");
		SetVariantString("0.5");
		AcceptEntityInput(npc.m_iWearable1, "SetModelScale");
		
		return npc;
	}
}

public void BarrackVillager_ClotThink(int iNPC)
{
	BarrackVillager npc = view_as<BarrackVillager>(iNPC);
	float GameTime = GetGameTime(iNPC);
	npc.m_flSpeed = 150.0;
	if(BarrackBody_ThinkStart(npc.index, GameTime))
	{
		if(npc.i_VillagerSpecialCommand != Villager_Command_GatherResource)
		{
			if(IsValidEntity(npc.m_iWearable2))
				RemoveEntity(npc.m_iWearable2);
			
			if(!IsValidEntity(npc.m_iWearable1))
			{
				npc.m_iWearable1 = npc.EquipItem("weapon_bone", "models/workshop/weapons/c_models/c_sledgehammer/c_sledgehammer.mdl");
				SetVariantString("0.5");
				AcceptEntityInput(npc.m_iWearable1, "SetModelScale");		
			}		
		}
		else
		{
			if(IsValidEntity(npc.m_iWearable1))
				RemoveEntity(npc.m_iWearable1);

			if(!IsValidEntity(npc.m_iWearable2))
			{
				npc.m_iWearable2 = npc.EquipItem("weapon_bone", "models/weapons/c_models/c_pickaxe/c_pickaxe.mdl");
				SetVariantString("1.0");
				AcceptEntityInput(npc.m_iWearable2, "SetModelScale");		
			}
		}

		int client = GetClientOfUserId(npc.OwnerUserId);
		//	npc.SetActivity("ACT_VILLAGER_BUILD_LOOP");
		bool ListenToCustomCommands = true;
		bool IngoreBarracksCommands = false;
		int BuildingAlive = npc.m_iTowerLinked;
		if(!IsValidEntity(BuildingAlive))
		{
			if(VillagerDesiredBuildLocation[npc.index][0] != 0.0 && npc.f_VillagerBuildCooldown < GameTime)
			{
				ListenToCustomCommands = false;
				IngoreBarracksCommands = true;
				//We move to this position
				if(npc.m_iChanged_WalkCycle != 5) //walk to building
				{
					npc.m_iChanged_WalkCycle = 5;
					npc.StartPathing();
					npc.m_bisWalking = true;
					npc.SetActivity("ACT_VILLAGER_RUN");
				}	
				NPC_SetGoalVector(npc.index, VillagerDesiredBuildLocation[npc.index]);
				float MePos[3];
				GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", MePos);

				
				float flDistanceToTarget = GetVectorDistance(VillagerDesiredBuildLocation[npc.index], MePos, true);

				if(flDistanceToTarget < (50.0*50.0))
				{
					//We are close enough to build, lets build.
					int spawn_index = Npc_Create(BARRACKS_BUILDING, client, VillagerDesiredBuildLocation[npc.index], {0.0,0.0,0.0}, GetEntProp(npc.index, Prop_Send, "m_iTeamNum") == 2);
					if(spawn_index > MaxClients)
					{
						VillagerDesiredBuildLocation[npc.index][0] = 0.0;
						VillagerDesiredBuildLocation[npc.index][1] = 0.0;
						VillagerDesiredBuildLocation[npc.index][2] = 0.0;
						npc.f_VillagerBuildCooldown = GameTime + 120.0;
						npc.m_iTowerLinked = spawn_index;
						BarrackVillager player = view_as<BarrackVillager>(client);
						player.m_iTowerLinked = spawn_index;
						if(!b_IsAlliedNpc[iNPC])
						{
							Zombies_Currently_Still_Ongoing += 1;
						}
						i_AttacksTillMegahit[spawn_index] = 10;
						SetEntProp(spawn_index, Prop_Data, "m_iHealth", 1); //only 1 health, the villager needs to first needs to build it up over time.
						SetEntityRenderMode(spawn_index, RENDER_TRANSCOLOR);
						SetEntityRenderColor(spawn_index, 255, 255, 255, 0);
					}
				}
			}
			else if(IsValidClient(client))
			{
				if(npc.f_VillagerRemind < GameTime && npc.f_VillagerBuildCooldown < GameTime)
				{
					npc.f_VillagerRemind = GameTime + 10.0;
					switch(GetRandomInt(1,4))
					{
						case 1:
						{
							CPrintToChat(client, "{green}Villager Minion{default}: Please tell me where to build my tower!");
						}
						case 2:
						{
							CPrintToChat(client, "{green}Villager Minion{default}: Mister, i will need a command on where to build!");
						}
						case 3:
						{
							CPrintToChat(client, "{green}Villager Minion{default}: I wish to build a tower, please tell me where!");
						}
						case 4:
						{
							CPrintToChat(client, "{green}Villager Minion{default}: I'm in need of commands on where to build!");
						}
					}
				}		
			}
		}
		else
		{
			//our building now exists, lets build it if we are close enough, we ignore any other command.
			if(i_AttacksTillMegahit[BuildingAlive] < 255)
			{
				IngoreBarracksCommands = true;
				ListenToCustomCommands = false;
				float BuildingPos[3];
				GetEntPropVector(BuildingAlive, Prop_Data, "m_vecAbsOrigin", BuildingPos);
				float MePos[3];
				GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", MePos);
				float flDistanceToTarget = GetVectorDistance(BuildingPos, MePos, true);
				if(flDistanceToTarget < (50.0*50.0)) //we are close enough, lets build.
				{
					i_AttacksTillMegahit[BuildingAlive] += 1;
					if(GetEntProp(BuildingAlive, Prop_Data, "m_iHealth") < GetEntProp(BuildingAlive, Prop_Data, "m_iMaxHealth"))
					{
						SetEntProp(BuildingAlive, Prop_Data, "m_iHealth", GetEntProp(BuildingAlive, Prop_Data, "m_iHealth") + (GetEntProp(BuildingAlive, Prop_Data, "m_iMaxHealth") / 222));
						if(GetEntProp(BuildingAlive, Prop_Data, "m_iHealth") >= GetEntProp(BuildingAlive, Prop_Data, "m_iMaxHealth"))
						{
							SetEntProp(BuildingAlive, Prop_Data, "m_iHealth", GetEntProp(BuildingAlive, Prop_Data, "m_iMaxHealth"));
						}
					}
					npc.FaceTowards(BuildingPos, 10000.0); //build.
					if(npc.m_iChanged_WalkCycle != 6)
					{
						npc.m_iChanged_WalkCycle = 6;
						NPC_StopPathing(npc.index);
						npc.m_bisWalking = false;
						npc.SetActivity("ACT_VILLAGER_BUILD_LOOP");
					}	
				}
				else //Lets move to the building.
				{
					if(npc.m_iChanged_WalkCycle != 5) //walk to building
					{
						npc.m_iChanged_WalkCycle = 5;
						npc.StartPathing();
						npc.m_bisWalking = true;
						npc.SetActivity("ACT_VILLAGER_RUN");
					}	
					NPC_SetGoalVector(npc.index, BuildingPos);
				}
			}
			else if(i_AttacksTillMegahit[BuildingAlive] != 300) //300 indicates its finished building.
			{
				IngoreBarracksCommands = true;
				ListenToCustomCommands = false;
				i_AttacksTillMegahit[BuildingAlive] = 255;
				//we are done.
			}
			else
			{
				ListenToCustomCommands = true;
			}
		}
		if(ListenToCustomCommands)
		{
			//we will now obey any command incase we werent given an order to build a tower.
			switch(npc.i_VillagerSpecialCommand)
			{
				//we stay near whatever we have been made to be near, we repair, we build, we run.
				case Villager_Command_GatherResource:
				{
					IngoreBarracksCommands = true;
					float MePos[3];
					GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", MePos);
					float flDistanceToTarget = GetVectorDistance(VillagerRepairFocusLoc[npc.index], MePos, true);
					if(flDistanceToTarget < (25.0*25.0))
					{
						// 1 Supply = 1 Food Every 2 Seconds, 1 Wood Every 4 Seconds
						float SupplyRateCalc = SupplyRate[client] / (LastMann ? 20.0 : 40.0);

						if(i_NormalBarracks_HexBarracksUpgrades[client] & ZR_BARRACKS_UPGRADES_CONSCRIPTION)
						{
							SupplyRateCalc *= 1.25;
						}
						WoodAmount[client] += SupplyRateCalc;
						FoodAmount[client] += SupplyRateCalc * 2.0; //food is gained 2x as fast

						// 1 Supply = 1 Gold Every 150 Seconds
						float GoldSupplyRate = SupplyRate[client] / 1500.0;
						if(i_NormalBarracks_HexBarracksUpgrades[client] & ZR_BARRACKS_UPGRADES_GOLDMINERS)
						{
							GoldSupplyRate *= 1.25;
						}
						GoldAmount[client] += GoldSupplyRate;
						if(npc.m_iChanged_WalkCycle != 7)
						{
							npc.m_iChanged_WalkCycle = 7;
							NPC_StopPathing(npc.index);
							npc.m_bisWalking = false;
							npc.SetActivity("ACT_VILLAGER_MINING"); //mining animation?
						}	
					}
					else
					{
						if(npc.m_iChanged_WalkCycle != 5) //walk to building
						{
							npc.m_iChanged_WalkCycle = 5;
							npc.StartPathing();
							npc.m_bisWalking = true;
							npc.SetActivity("ACT_VILLAGER_RUN");
						}	
						NPC_SetGoalVector(npc.index, VillagerRepairFocusLoc[npc.index]);
					}
				}
				case Villager_Command_StandNearTower:
				{
					if(BarracksVillager_RepairSelfTower(npc.index, BuildingAlive))
					{
						IngoreBarracksCommands = true;
						//uhhh....
					}
					else
					{
						if(BuildingAlive > 0)
						{
							IngoreBarracksCommands = true;
							float BuildingPos[3];
							GetEntPropVector(BuildingAlive, Prop_Data, "m_vecOrigin", BuildingPos);
							int Closest_Building = GetClosestBuildingVillager(npc.index, BuildingPos, (750.0 * 750.0));

							if(Closest_Building > 0)
							{
								BarracksVillager_RepairBuilding(npc.index, Closest_Building);
							}
							else
							{
								float MePos[3];
								GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", MePos);
								float flDistanceToTarget = GetVectorDistance(BuildingPos, MePos, true);

								if(flDistanceToTarget < (25.0*25.0))
								{
									if(npc.m_iChanged_WalkCycle != 4)
									{
										npc.m_iChanged_WalkCycle = 4;
										NPC_StopPathing(npc.index);
										npc.m_bisWalking = false;
										npc.SetActivity("ACT_VILLAGER_IDLE");
									}	
								}
								else
								{
									if(npc.m_iChanged_WalkCycle != 5) //walk to building
									{
										npc.m_iChanged_WalkCycle = 5;
										npc.StartPathing();
										npc.m_bisWalking = true;
										npc.SetActivity("ACT_VILLAGER_RUN");
									}	
									NPC_SetGoalVector(npc.index, BuildingPos);
								}
							}
						}
					}					
				}
				case Villager_Command_Default:
				{
					if(BarracksVillager_RepairSelfTower(npc.index, BuildingAlive))
					{
						IngoreBarracksCommands = true;
					}
					else
					{
						BarrackBody_ThinkTarget(npc.index, true, GameTime, true); //we are passive, we do not attack, we just repair.
						float MePos[3];
						GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", MePos);

						int Closest_Building = GetClosestBuildingVillager(npc.index, MePos, (750.0 * 750.0));

						if(Closest_Building > 0)
						{
							BarracksVillager_RepairBuilding(npc.index, Closest_Building);
							IngoreBarracksCommands = true;
						}
					}
				}
				case Villager_Command_RepairFocus:
				{
					if(BarracksVillager_RepairSelfTower(npc.index, BuildingAlive))
					{
						IngoreBarracksCommands = true;
					}
					else
					{
						// we ingore any command now from default barracks, we got assigned a position and we will now repair everything in this area.
						int Closest_Building = GetClosestBuildingVillager(npc.index, VillagerRepairFocusLoc[npc.index], (750.0 * 750.0));

						if(Closest_Building < 1)
						{
							float MePos[3];
							GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", MePos);
							float flDistanceToTarget = GetVectorDistance(VillagerRepairFocusLoc[npc.index], MePos, true);
							//we have no building to repair! ahh!
							//be lazy :)
							if(flDistanceToTarget < (25.0*25.0))
							{
								if(npc.m_iChanged_WalkCycle != 4)
								{
									npc.m_iChanged_WalkCycle = 4;
									NPC_StopPathing(npc.index);
									npc.m_bisWalking = false;
									npc.SetActivity("ACT_VILLAGER_IDLE");
								}	
							}
							else
							{
								if(npc.m_iChanged_WalkCycle != 5) //walk back home.
								{
									npc.m_iChanged_WalkCycle = 5;
									npc.StartPathing();
									npc.m_bisWalking = true;
									npc.SetActivity("ACT_VILLAGER_RUN");
								}	
								NPC_SetGoalVector(npc.index, VillagerRepairFocusLoc[npc.index]);
							}
						}
						else
						{
							IngoreBarracksCommands = true;
							BarracksVillager_RepairBuilding(npc.index, Closest_Building);
							//building found thats hurt, repair.
						}
					}
				}
			}
		}
		if(!IngoreBarracksCommands)
			BarrackBody_ThinkMove(npc.index, 150.0, "ACT_VILLAGER_IDLE", "ACT_VILLAGER_RUN");
	}
}

void BarrackVillager_NPCDeath(int entity)
{
	BarrackVillager npc = view_as<BarrackVillager>(entity);
	BarrackBody_NPCDeath(npc.index);
	SDKUnhook(npc.index, SDKHook_Think, BarrackVillager_ClotThink);
}

bool BarracksVillager_RepairSelfTower(int entity, int tower)
{
	if(tower < 0) //woops, tower is fucking dead.
	{
		return false;
	}
	if(GetEntProp(tower, Prop_Data, "m_iHealth") >= GetEntProp(tower, Prop_Data, "m_iMaxHealth"))
	{
		return false;
	}
	BarrackVillager npc = view_as<BarrackVillager>(entity);
	float MePos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", MePos);
	float BuildingPos[3];
	GetEntPropVector(tower, Prop_Data, "m_vecOrigin", BuildingPos);
	float flDistanceToTarget = GetVectorDistance(BuildingPos, MePos, true);
	if(flDistanceToTarget > (500.0*500.0)) //i am too far away from my tower, i wont bother.
	{
		return false;
	}
	bool BuldingCanBeRepaired = false;
	if(flDistanceToTarget < (50.0*50.0))
	{
		BuldingCanBeRepaired = true;
		npc.FaceTowards(BuildingPos, 10000.0); //build.
		if(npc.m_iChanged_WalkCycle != 6)
		{
			npc.m_iChanged_WalkCycle = 6;
			NPC_StopPathing(npc.index);
			npc.m_bisWalking = false;
			npc.SetActivity("ACT_VILLAGER_BUILD_LOOP");
		}	
	}
	else
	{
		if(npc.m_iChanged_WalkCycle != 5) //walk to building
		{
			npc.m_iChanged_WalkCycle = 5;
			npc.StartPathing();
			npc.m_bisWalking = true;
			npc.SetActivity("ACT_VILLAGER_RUN");
		}	
		NPC_SetGoalVector(npc.index, BuildingPos);
	}
	if(BuldingCanBeRepaired)
	{
		if(GetEntProp(tower, Prop_Data, "m_iHealth") < GetEntProp(tower, Prop_Data, "m_iMaxHealth"))
		{
			SetEntProp(tower, Prop_Data, "m_iHealth", GetEntProp(tower, Prop_Data, "m_iHealth") + (GetEntProp(tower, Prop_Data, "m_iMaxHealth") / 500));
			if(GetEntProp(tower, Prop_Data, "m_iHealth") >= GetEntProp(tower, Prop_Data, "m_iMaxHealth"))
			{
				SetEntProp(tower, Prop_Data, "m_iHealth", GetEntProp(tower, Prop_Data, "m_iMaxHealth"));
			}
		}
	}
	return true;
}

void BarracksVillager_RepairBuilding(int entity, int building)
{
	float MePos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", MePos);
	float BuildingPos[3];
	GetEntPropVector(building, Prop_Data, "m_vecOrigin", BuildingPos);
	float flDistanceToTarget = GetVectorDistance(BuildingPos, MePos, true);
	BarrackVillager npc = view_as<BarrackVillager>(entity);
	//we have no building to repair! ahh!
	//be lazy :)
	bool BuldingCanBeRepaired = false;
	if(flDistanceToTarget < (50.0*50.0))
	{
		BuldingCanBeRepaired = true;
		npc.FaceTowards(BuildingPos, 10000.0); //build.
		if(npc.m_iChanged_WalkCycle != 6)
		{
			npc.m_iChanged_WalkCycle = 6;
			NPC_StopPathing(npc.index);
			npc.m_bisWalking = false;
			npc.SetActivity("ACT_VILLAGER_BUILD_LOOP");
		}	
	}
	else
	{
		if(npc.m_iChanged_WalkCycle != 5) //walk to building
		{
			npc.m_iChanged_WalkCycle = 5;
			npc.StartPathing();
			npc.m_bisWalking = true;
			npc.SetActivity("ACT_VILLAGER_RUN");
		}	
		NPC_SetGoalVector(npc.index, BuildingPos);
	}
	if(BuldingCanBeRepaired)
	{
		if(GetEntProp(building, Prop_Data, "m_iHealth") < GetEntProp(building, Prop_Data, "m_iMaxHealth"))
		{
			SetEntProp(building, Prop_Data, "m_iHealth", GetEntProp(building, Prop_Data, "m_iHealth") + (GetEntProp(building, Prop_Data, "m_iMaxHealth") / 500));
			if(GetEntProp(building, Prop_Data, "m_iHealth") >= GetEntProp(building, Prop_Data, "m_iMaxHealth"))
			{
				SetEntProp(building, Prop_Data, "m_iHealth", GetEntProp(building, Prop_Data, "m_iMaxHealth"));
			}
		}
	}
}

void BarracksVillager_MenuSpecial(int client, int entity)
{
	BarrackVillager npc = view_as<BarrackVillager>(entity);

	Menu menu = new Menu(BarrackVillager_MenuH);
	menu.SetTitle("%t\n \n%t\n ", "TF2: Zombie Riot", NPC_Names[i_NpcInternalId[entity]]);
	BarrackVillager player = view_as<BarrackVillager>(client);
	char num[16];
	IntToString(EntIndexToEntRef(entity), num, sizeof(num));
	menu.AddItem(num, "Default Engagement", npc.i_VillagerSpecialCommand == Villager_Command_Default ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem(num, "Place Tower There", IsValidEntity(player.m_iTowerLinked) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem(num, "Repair This", npc.i_VillagerSpecialCommand == Villager_Command_RepairFocus ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem(num, "Gather Resources", ITEMDRAW_DEFAULT);
	menu.AddItem(num, "Stand Near Tower", npc.i_VillagerSpecialCommand == Villager_Command_StandNearTower ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	menu.Pagination = 0;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);	
}


public int BarrackVillager_MenuH(Menu menu, MenuAction action, int client, int choice)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char num[16];
			menu.GetItem(choice, num, sizeof(num));

			int entity = EntRefToEntIndex(StringToInt(num));
			if(entity != INVALID_ENT_REFERENCE)
			{
				BarrackVillager npc = view_as<BarrackVillager>(entity);
				float GameTime = GetGameTime(entity);

				switch(choice)
				{
					case 0:
					{
						npc.i_VillagerSpecialCommand = Command_Default;
					}
					case 1:
					{
						if(npc.f_VillagerBuildCooldown < GameTime)
						{
							float StartOrigin[3], Angles[3], vecPos[3];
							GetClientEyeAngles(client, Angles);
							GetClientEyePosition(client, StartOrigin);
							Handle TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, (MASK_NPCSOLID_BRUSHONLY), RayType_Infinite, TraceRayProp);
							if (TR_DidHit(TraceRay))
								TR_GetEndPosition(vecPos, TraceRay);
								
							delete TraceRay;
							npc.FaceTowards(vecPos, 10000.0);
							CreateParticle("ping_circle", vecPos, NULL_VECTOR);

							CNavArea area = TheNavMesh.GetNavArea(vecPos, 25.0);
							if(area == NULL_AREA)
							{
								CPrintToChat(client, "{green}Villager Minion{default}: I can't build here, please place it closer to the ground or away from walls!");		
							}
							else
							{
								vecPos[2] += 18.0;
								if(IsPointHazard(vecPos)) //Retry.
								{
									CPrintToChat(client, "{green}Villager Minion{default}: I can't build here, please place it closer to the ground or away from walls!");		
									BarracksVillager_MenuSpecial(client, npc.index);
									return 0;
								}

								
								vecPos[2] -= 18.0;
								if(IsPointHazard(vecPos)) //Retry.
								{
									CPrintToChat(client, "{green}Villager Minion{default}: I can't build here, please place it closer to the ground or away from walls!");		
									BarracksVillager_MenuSpecial(client, npc.index);
									return 0;
								}
								VillagerDesiredBuildLocation[npc.index] = vecPos;
								
								CPrintToChat(client, "{green}Villager Minion{default}: Right ahead sir!");			
							}
						}	
						else
						{
							switch(GetRandomInt(1,2))
							{
								case 1:
								{
									CPrintToChat(client, "{green}Villager Minion{default}: I'm sorry i dont have the resources right now. [%.1f]",npc.f_VillagerBuildCooldown - GameTime);
								}
								case 2:
								{
									CPrintToChat(client, "{green}Villager Minion{default}: I currently can't build my tower, i need more resources, please wait! [%.1f]",npc.f_VillagerBuildCooldown - GameTime);
								}
							}
						}					
						npc.i_VillagerSpecialCommand = Command_Default;
					}
					case 2:
					{
						float StartOrigin[3], Angles[3], vecPos[3];
						GetClientEyeAngles(client, Angles);
						GetClientEyePosition(client, StartOrigin);
						Handle TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, (MASK_NPCSOLID_BRUSHONLY), RayType_Infinite, TraceRayProp);
						if (TR_DidHit(TraceRay))
							TR_GetEndPosition(vecPos, TraceRay);
								
						delete TraceRay;
						npc.FaceTowards(vecPos, 10000.0);
						CreateParticle("ping_circle", vecPos, NULL_VECTOR);
						VillagerRepairFocusLoc[npc.index] = vecPos;

						npc.i_VillagerSpecialCommand = Villager_Command_RepairFocus;
					}
					case 3:
					{
						float StartOrigin[3], Angles[3], vecPos[3];
						GetClientEyeAngles(client, Angles);
						GetClientEyePosition(client, StartOrigin);
						Handle TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, (MASK_NPCSOLID_BRUSHONLY), RayType_Infinite, TraceRayProp);
						if (TR_DidHit(TraceRay))
							TR_GetEndPosition(vecPos, TraceRay);
								
						delete TraceRay;
						npc.FaceTowards(vecPos, 10000.0);
						CreateParticle("ping_circle", vecPos, NULL_VECTOR);
						VillagerRepairFocusLoc[npc.index] = vecPos;

						npc.i_VillagerSpecialCommand = Villager_Command_GatherResource;
					}
					case 4:
					{
						npc.i_VillagerSpecialCommand = Villager_Command_StandNearTower;
					}
				}
				BarracksVillager_MenuSpecial(client, npc.index);
			}
		}
	}
	return 0;
}


stock int GetClosestBuildingVillager(int entity, float EntityLocation[3], float limitsquared = 99999999.9)
{
	float TargetDistance = 0.0; 
	int ClosestTarget = 0; 
	for(int entitycount; entitycount<i_MaxcountBuilding; entitycount++) //BUILDINGS!
	{
		int building = EntRefToEntIndex(i_ObjectsBuilding[entitycount]);
		if(IsValidEntity(building) && GetEntProp(building, Prop_Data, "m_iHealth") < GetEntProp(building, Prop_Data, "m_iMaxHealth"))
		{
			if(Can_I_See_Enemy_Only(entity, building))
			{
				float TargetLocation[3]; 
				GetEntPropVector( building, Prop_Data, "m_vecOrigin", TargetLocation ); //buildings do not have abs origin? 
				float distance = GetVectorDistance( EntityLocation, TargetLocation, true ); 
				if( distance < limitsquared )
				{
					if( TargetDistance ) 
					{
						if( distance < TargetDistance ) 
						{
							ClosestTarget = building; 
							TargetDistance = distance;		  
						}
					} 
					else 
					{
						ClosestTarget = building; 
						TargetDistance = distance;
					}			
				}
			}
		}
	}
	return ClosestTarget; 
}