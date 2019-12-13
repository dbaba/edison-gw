/**
 * @license
 * Copyright (c) 2019 CANDY LINE INC.
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
 */

import 'source-map-support/register';
import { DefaultDeviceIdResolver } from './device-id-resolver';
import { DeviceState } from './device-state';
import { LwM2MDeviceManagement } from './lwm2m-device-management';

export { DefaultDeviceIdResolver, DeviceState, LwM2MDeviceManagement };

export class DeviceManagerStore {
  constructor() {
    this.store = {};
    this.deviceState = new DeviceState(
      this._onFlowFileChangedFunc(),
      this._onFlowFileRemovedFunc()
    );
    this.lwm2m = new LwM2MDeviceManagement(this.deviceState);
  }

  _onFlowFileChangedFunc() {
    return (() => {
      return () => {
        return new Promise(resolve => {
          // TODO
          return resolve();
        });
      };
    })();
  }

  _onFlowFileRemovedFunc() {
    return (() => {
      return () => {
        return new Promise(resolve => {
          // TODO
          return resolve();
        });
      };
    })();
  }
}
