shader_type spatial;

uniform sampler2D decal : hint_black;
uniform vec2 scale;
uniform vec2 offset;

void fragment()
{
	vec2 pos = vec2(0);
	pos.x = (UV.x - offset.x) / scale.x;
	pos.y = (UV.y - offset.y) / scale.y;
	
	bool inside = all(greaterThanEqual(pos, vec2(-0.5))) && all(lessThanEqual(pos, vec2(0.5)));
	
	if(inside)
	{
		vec4 colour = texture(decal, pos + vec2(0.5));
		
		ALBEDO = colour.rgb;
		ALPHA = colour.a;
	}
	else
	{
		discard;
	}
}
