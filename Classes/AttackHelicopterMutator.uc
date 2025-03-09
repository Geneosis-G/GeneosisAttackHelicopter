class AttackHelicopterMutator extends GGMutator;

struct GoatAttackHelicopter
{
	var GGGoat mGoat;
	var AttackHelicopterVehicle mAttackHelicopter;
};
var array<GoatAttackHelicopter> mGoatAttackHelicopters;


/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;

	goat = GGGoat( other );
	if( goat != none )
	{
		if( IsValidForPlayer( goat ) )
		{
			AddGoatAttackHelicopter(goat);
		}
	}

	super.ModifyPlayer( other );
}

function AddGoatAttackHelicopter(GGGoat goat)
{
	local GoatAttackHelicopter newGoatAttackHelicopter;

	if(mGoatAttackHelicopters.Find('mGoat', goat) == INDEX_NONE)
	{
		newGoatAttackHelicopter.mGoat=goat;
		mGoatAttackHelicopters.AddItem(newGoatAttackHelicopter);
	}
}

simulated event Tick( float deltaTime )
{
	local int i;
	local vector spawnLoc;
	local rotator spawnRot;

	super.Tick( deltaTime );

	for(i=0 ; i<mGoatAttackHelicopters.Length ; i++)
	{
		if(mGoatAttackHelicopters[i].mGoat == none || mGoatAttackHelicopters[i].mGoat.bPendingDelete)
			continue;

		if(mGoatAttackHelicopters[i].mAttackHelicopter == none || mGoatAttackHelicopters[i].mAttackHelicopter.bPendingDelete)
		{
			spawnLoc=mGoatAttackHelicopters[i].mGoat.Location + (Normal(vector(mGoatAttackHelicopters[i].mGoat.Rotation)) * 1000.f);
			spawnLoc.Z = spawnLoc.Z - mGoatAttackHelicopters[i].mGoat.GetCollisionHeight();
			spawnRot.Yaw = mGoatAttackHelicopters[i].mGoat.Rotation.Yaw + 16384;

			mGoatAttackHelicopters[i].mAttackHelicopter=Spawn(class'AttackHelicopterVehicle', mGoatAttackHelicopters[i].mGoat,, spawnLoc, spawnRot);
		}

		mGoatAttackHelicopters[i].mAttackHelicopter.currentBaseY=PlayerController( mGoatAttackHelicopters[i].mAttackHelicopter.Controller ).PlayerInput.aBaseY;
		mGoatAttackHelicopters[i].mAttackHelicopter.currentStrafe=PlayerController( mGoatAttackHelicopters[i].mAttackHelicopter.Controller ).PlayerInput.aStrafe;
	}
}

/**
 * Called when a pawn is possessed by a controller.
 */
function NotifyOnPossess( Controller C, Pawn P )
{
	local int i;

	super.NotifyOnPossess(C, P);

	for(i=0 ; i<mGoatAttackHelicopters.Length ; i++)
	{
		mGoatAttackHelicopters[i].mAttackHelicopter.NotifyOnPossess(C, P);
	}
}

/**
 * Called when a pawn is unpossessed by a controller.
 */
function NotifyOnUnpossess( Controller C, Pawn P )
{
	local int i;

	super.NotifyOnUnpossess(C, P);

	for(i=0 ; i<mGoatAttackHelicopters.Length ; i++)
	{
		mGoatAttackHelicopters[i].mAttackHelicopter.NotifyOnUnpossess(C, P);
	}
}

function OnBaa( GGGoat goat )
{
	local int i;

	super.OnBaa(goat);

	if(goat.mIsRagdoll)
	{
		for(i=0 ; i<mGoatAttackHelicopters.Length ; i++)
		{
			if(mGoatAttackHelicopters[i].mGoat == goat && mGoatAttackHelicopters[i].mAttackHelicopter.Driver == none)
			{
				mGoatAttackHelicopters[i].mAttackHelicopter.expectedPosition = goat.mesh.GetPosition() + vect(0, 0, 1000);
				mGoatAttackHelicopters[i].mAttackHelicopter.LockPosition();
			}
		}
	}
}

/*function OnCollision( Actor actor0, Actor actor1 )
{
	super.OnCollision( actor0, actor1 );

	if(GGGoat(actor0) != none || GGGoat(actor1) != none)
	{
		WorldInfo.Game.Broadcast(self, actor0 $ " collided with " $ actor1);
	}
}*/

DefaultProperties
{

}