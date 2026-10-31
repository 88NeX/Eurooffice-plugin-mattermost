// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

/**
 *
 * (c) Copyright Ascensio System SIA 2026
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import {id as pluginName} from 'manifest';

import {http} from './http';

const EuroOffice_PLUGIN_API = `/plugins/${pluginName}/api`;
export const EuroOffice_PLUGIN_PERMISSIONS = `${EuroOffice_PLUGIN_API}/permissions`;
export const EuroOffice_PLUGIN_GET_CODE = `${EuroOffice_PLUGIN_API}/code`;
export const EuroOffice_PLUGIN_CREATE = `${EuroOffice_PLUGIN_API}/create`;
export const EuroOffice_PLUGIN_CONVERT = `${EuroOffice_PLUGIN_API}/convert`;
export const EuroOffice_PLUGIN_CONFIG = `${EuroOffice_PLUGIN_API}/config`;

export async function get<T>(path: string, config?: RequestInit): Promise<T> {
    const init = {method: 'GET', ...config};
    return http<T>(path, init);
}

export async function post<T, U>(path: string, body: T, config?: RequestInit): Promise<U> {
    const init = {method: 'POST', body: JSON.stringify(body), ...config};
    return http<U>(path, init);
}

export interface PluginConfig {
    formats: string[];
    ownerProtected: boolean;
    pluginsEnabled: boolean;
    macrosEnabled: boolean;
}

export async function getPluginConfig(): Promise<PluginConfig> {
    return get<PluginConfig>(EuroOffice_PLUGIN_CONFIG);
}

export interface HealthStatus {
    healthy: boolean;
    time: number;
}

export async function getHealthStatus(): Promise<HealthStatus> {
    return get<HealthStatus>(EuroOffice_PLUGIN_API + '/health');
}
