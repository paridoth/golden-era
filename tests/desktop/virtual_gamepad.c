// SPDX-License-Identifier: GPL-3.0-or-later
// Test-only SDL virtual controller. Commands are processed on SDL's event thread.
#define _GNU_SOURCE
#include <SDL.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int SDL_PollEvent(SDL_Event *event)
{
	static int (*real_poll)(SDL_Event *);
	static SDL_Joystick *joystick;
	static FILE *commands, *acks;
	static unsigned sequence;
	if (!real_poll)
		real_poll = (int (*)(SDL_Event *))dlsym(RTLD_NEXT, "SDL_PollEvent");
	if (!commands && getenv("GE_CONTROLLER_COMMANDS")) {
		commands = fopen(getenv("GE_CONTROLLER_COMMANDS"), "r");
		acks = fopen(getenv("GE_CONTROLLER_ACKS"), "a");
		int index = SDL_JoystickAttachVirtual(SDL_JOYSTICK_TYPE_GAMECONTROLLER, 6, 21, 0);
		if (index < 0 || !(joystick = SDL_JoystickOpen(index))) {
			fprintf(stderr, "Virtual controller failed: %s\n", SDL_GetError());
			exit(90);
		}
		char guid[33], mapping[512];
		SDL_JoystickGetGUIDString(SDL_JoystickGetGUID(joystick), guid, sizeof(guid));
		snprintf(mapping, sizeof(mapping), "%s,Golden Era virtual test controller,"
			"a:b0,b:b1,x:b2,y:b3,back:b4,guide:b5,start:b6,leftstick:b7,rightstick:b8,"
			"leftshoulder:b9,rightshoulder:b10,dpup:b11,dpdown:b12,dpleft:b13,dpright:b14,"
			"leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:a4,righttrigger:a5,", guid);
		SDL_GameControllerAddMapping(mapping);
		fprintf(acks, "ready\n");
		fflush(acks);
	}
	if (commands) {
		char line[128], kind[32];
		int a = 0, b = 0;
		clearerr(commands);
		while (fgets(line, sizeof(line), commands)) {
			if (sscanf(line, "%31s %d %d", kind, &a, &b) < 1)
				continue;
			if (!strcmp(kind, "axis"))
				SDL_JoystickSetVirtualAxis(joystick, a, b);
			else if (!strcmp(kind, "button"))
				SDL_JoystickSetVirtualButton(joystick, a, b);
			else if (!strcmp(kind, "mouse"))
				SDL_WarpMouseInWindow(SDL_GetWindowFromID(1), a, b);
			else if (!strcmp(kind, "focus"))
				SDL_SetWindowInputFocus(SDL_GetWindowFromID(1));
			else if (!strcmp(kind, "quit")) {
				SDL_Event quit = {.type = SDL_QUIT};
				SDL_PushEvent(&quit);
			}
			fprintf(acks, "%u %s", ++sequence, line);
			fflush(acks);
		}
	}
	return real_poll(event);
}
