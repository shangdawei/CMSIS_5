;/*
; * Copyright (c) 2013-2016 ARM Limited. All rights reserved.
; *
; * SPDX-License-Identifier: Apache-2.0
; *
; * Licensed under the Apache License, Version 2.0 (the License); you may
; * not use this file except in compliance with the License.
; * You may obtain a copy of the License at
; *
; * http://www.apache.org/licenses/LICENSE-2.0
; *
; * Unless required by applicable law or agreed to in writing, software
; * distributed under the License is distributed on an AS IS BASIS, WITHOUT
; * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; * See the License for the specific language governing permissions and
; * limitations under the License.
; *
; * -----------------------------------------------------------------------------
; *
; * Project:     CMSIS-RTOS RTX
; * Title:       Cortex-M3 Exception handlers
; *
; * -----------------------------------------------------------------------------
; */


                PRESERVE8
                THUMB

I_T_RUN_OFS     EQU     28                      ; osInfo.thread.run offset
TCB_SP_OFS      EQU     56                      ; TCB.SP offset

                AREA    |.constdata|, DATA, READONLY
                EXPORT  os_irq_cm
os_irq_cm       DCB     0                       ; Non weak library reference

                AREA    |.text|, CODE, READONLY


SVC_Handler     PROC
                EXPORT  SVC_Handler
                IMPORT  os_UserSVC_Table
                IMPORT  os_Info

                MRS     R0,PSP                  ; Get PSP
                LDR     R1,[R0,#24]             ; Load saved PC from stack
                LDRB    R1,[R1,#-2]             ; Load SVC number
                CBNZ    R1,SVC_User             ; Branch if not SVC 0

                LDM     R0,{R0-R3,R12}          ; Load function parameters and address from stack
                BLX     R12                     ; Call service function
                MRS     R12,PSP                 ; Get PSP
                STR     R0,[R12]                ; Store function return value

SVC_Context
                LDR     R3,=os_Info+I_T_RUN_OFS ; Load address of os_Info.run
                LDM     R3,{R1,R2}              ; Load os_Info.thread.run: curr & next
                CMP     R1,R2                   ; Check if thread switch is required
                BEQ     SVC_Exit                ; Branch when threads are the same

                CBZ     R1,SVC_ContextSwitch    ; Branch if running thread is deleted

SVC_ContextSave
                STMDB   R12!,{R4-R11}           ; Save R4..R11
                STR     R12,[R1,#TCB_SP_OFS]    ; Store SP

SVC_ContextSwitch
                STR     R2,[R3]                 ; os_Info.thread.run: curr = next

SVC_ContextRestore
                LDR     R12,[R2,#TCB_SP_OFS]    ; Load SP
                LDMIA   R12!,{R4-R11}           ; Restore R4..R11
                MSR     PSP,R12                 ; Set PSP

SVC_Exit
                MVN     LR,#~0xFFFFFFFD         ; Set EXC_RETURN value
                BX      LR                      ; Exit from handler

SVC_User
                PUSH    {R4,LR}                 ; Save registers
                LDR     R2,=os_UserSVC_Table    ; Load address of SVC table
                LDR     R3,[R2]                 ; Load SVC maximum number
                CMP     R1,R3                   ; Check SVC number range
                BHI     SVC_Done                ; Branch if out of range

                LDR     R4,[R2,R1,LSL #2]       ; Load address of SVC function

                LDM     R0,{R0-R3}              ; Load function parameters from stack
                BLX     R4                      ; Call service function
                MRS     R12,PSP                 ; Get PSP
                STM     R12,{R0-R3}             ; Store function return values

SVC_Done
                POP     {R4,PC}                 ; Return from handler

                ALIGN
                ENDP


PendSV_Handler  PROC
                EXPORT  PendSV_Handler
                IMPORT  os_PendSV_Handler

                BL      os_PendSV_Handler
                MRS     R12,PSP
                B       SVC_Context

                ALIGN
                ENDP


SysTick_Handler PROC
                EXPORT  SysTick_Handler
                IMPORT  os_Tick_Handler

                BL      os_Tick_Handler
                MRS     R12,PSP
                B       SVC_Context

                ALIGN
                ENDP


                END
